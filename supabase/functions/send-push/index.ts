// Отправляет push-уведомления. Вызывается Database Webhook при вставке в notifications и messages.
// Секреты (Supabase → Edge Functions → Secrets): VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT.
// SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY Supabase передаёт сам.
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
  const body = await req.json();
  const rec = body.record ?? {};
  let userIds: string[] = [];
  let title = 'TAJ Bozor';
  let text = '';

  if (body.table === 'notifications') {
    userIds = [rec.user_id];
    title = rec.title ?? title;
    text = rec.body ?? '';
  } else if (body.table === 'messages') {
    // Получатель — собеседник отправителя в этой переписке.
    const { data: conv } = await db
      .from('conversations')
      .select('buyer_id, seller_id')
      .eq('id', rec.conversation_id)
      .maybeSingle();
    if (!conv) return new Response('no conversation', { status: 200 });
    const other = conv.buyer_id === rec.sender_id ? conv.seller_id : conv.buyer_id;
    if (!other) return new Response('no recipient', { status: 200 });
    userIds = [other];
    title = 'Новое сообщение';
    text = rec.body ?? '';
  } else {
    return new Response('unknown table', { status: 200 });
  }

  const { data: subs } = await db
    .from('push_subscriptions')
    .select('endpoint, p256dh, auth')
    .in('user_id', userIds);

  const payload = JSON.stringify({ title, body: text, url: '/' });
  await Promise.all(
    (subs ?? []).map(async (s) => {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
        );
      } catch (e) {
        // Подписка устарела (устройство отписалось): удаляем её.
        if (e.statusCode === 404 || e.statusCode === 410) {
          await db.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
        }
      }
    }),
  );

  return new Response('ok');
});
