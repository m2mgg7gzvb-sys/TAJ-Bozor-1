// Отправляет push-уведомления. Вызывается триггером БД при вставке в notifications и messages.
// Секреты (Supabase → Edge Functions → Secrets): VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT.
// SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY Supabase передаёт сам.
// Данные из запроса не доверяем: запись заново читается из базы по id.
import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

webpush.setVapidDetails(
  Deno.env.get('VAPID_SUBJECT')!,
  Deno.env.get('VAPID_PUBLIC_KEY')!,
  Deno.env.get('VAPID_PRIVATE_KEY')!,
);

const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response('bad json', { status: 400 });
  }
  const id = body?.record?.id;
  if (!id) return new Response('no id', { status: 400 });

  let userIds: string[] = [];
  let title = 'TAJ Bozor';
  let text = '';
  let url = '/';

  if (body.table === 'notifications') {
    const { data: n } = await db
      .from('notifications')
      .select('user_id, title, body')
      .eq('id', id)
      .maybeSingle();
    if (!n) return new Response('not found', { status: 200 });
    userIds = [n.user_id];
    title = n.title ?? title;
    text = n.body ?? '';
  } else if (body.table === 'messages') {
    const { data: m } = await db
      .from('messages')
      .select('sender_id, body, conversation_id')
      .eq('id', id)
      .maybeSingle();
    if (!m) return new Response('not found', { status: 200 });
    const { data: conv } = await db
      .from('conversations')
      .select('buyer_id, seller_id')
      .eq('id', m.conversation_id)
      .maybeSingle();
    if (!conv) return new Response('no conversation', { status: 200 });
    // Получатель — собеседник отправителя в этой переписке.
    const other = conv.buyer_id === m.sender_id ? conv.seller_id : conv.buyer_id;
    if (!other) return new Response('no recipient', { status: 200 });
    userIds = [other];
    title = 'Новое сообщение';
    text = m.body ?? '';
  } else {
    return new Response('unknown table', { status: 200 });
  }

  const { data: subs } = await db
    .from('push_subscriptions')
    .select('endpoint, p256dh, auth')
    .in('user_id', userIds);

  const payload = JSON.stringify({ title, body: text, url });
  await Promise.all(
    (subs ?? []).map(async (s) => {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
        );
      } catch (e: any) {
        // Подписка устарела (устройство отписалось): удаляем её.
        if (e?.statusCode === 404 || e?.statusCode === 410) {
          await db.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
        }
      }
    }),
  );

  return new Response('ok');
});
