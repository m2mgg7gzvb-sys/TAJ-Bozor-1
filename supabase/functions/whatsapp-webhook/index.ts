// Вебхук WhatsApp Cloud API (Meta). Получает сообщения, в которых человек отправил login_<nonce>,
// и записывает его номер в запрос входа. Сайт потом забирает вход через whatsapp-login.
// Секреты (Supabase → Edge Functions → Secrets):
//   WHATSAPP_VERIFY_TOKEN     — строка, которую вы сами придумали и вписали в настройках вебхука в Meta
//   WHATSAPP_APP_SECRET       — App Secret приложения Meta (для проверки подписи запроса)
//   WHATSAPP_ACCESS_TOKEN     — постоянный токен доступа (нужен только для ответов пользователю)
//   WHATSAPP_PHONE_NUMBER_ID  — ID номера в Cloud API (нужен только для ответов пользователю)
import { createClient } from 'npm:@supabase/supabase-js@2';

const VERIFY_TOKEN = Deno.env.get('WHATSAPP_VERIFY_TOKEN') ?? '';
const APP_SECRET = Deno.env.get('WHATSAPP_APP_SECRET') ?? '';
const ACCESS_TOKEN = Deno.env.get('WHATSAPP_ACCESS_TOKEN') ?? '';
const PHONE_NUMBER_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID') ?? '';
const TEN_MIN = 10 * 60 * 1000;

const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

function hex(buf: ArrayBuffer | Uint8Array): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// Проверка подписи Meta: заголовок X-Hub-Signature-256 = sha256=HMAC(App Secret, тело).
async function validSignature(raw: string, header: string | null): Promise<boolean> {
  if (!APP_SECRET || !header?.startsWith('sha256=')) return false;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(APP_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw)));
  const given = header.slice('sha256='.length);
  if (given.length !== mac.length) return false;
  let diff = 0;
  for (let i = 0; i < mac.length; i++) diff |= mac.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

async function reply(to: string, text: string) {
  if (!ACCESS_TOKEN || !PHONE_NUMBER_ID) return;
  await fetch(`https://graph.facebook.com/v21.0/${PHONE_NUMBER_ID}/messages`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${ACCESS_TOKEN}`,
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body: text },
    }),
  });
}

Deno.serve(async (req) => {
  // Подтверждение вебхука при настройке в Meta
  if (req.method === 'GET') {
    const url = new URL(req.url);
    if (
      url.searchParams.get('hub.mode') === 'subscribe' &&
      VERIFY_TOKEN &&
      url.searchParams.get('hub.verify_token') === VERIFY_TOKEN
    ) {
      return new Response(url.searchParams.get('hub.challenge') ?? '', { status: 200 });
    }
    return new Response('forbidden', { status: 403 });
  }
  if (req.method !== 'POST') return new Response('ok');

  const raw = await req.text();
  if (!(await validSignature(raw, req.headers.get('x-hub-signature-256')))) {
    return new Response('forbidden', { status: 403 });
  }

  let payload: any;
  try {
    payload = JSON.parse(raw);
  } catch {
    return new Response('ok');
  }

  for (const entry of payload?.entry ?? []) {
    for (const change of entry?.changes ?? []) {
      const value = change?.value;
      const names: Record<string, string> = {};
      for (const c of value?.contacts ?? []) {
        if (c?.wa_id) names[c.wa_id] = c?.profile?.name ?? '';
      }
      for (const msg of value?.messages ?? []) {
        const from: string = String(msg?.from ?? '');
        const text: string = typeof msg?.text?.body === 'string' ? msg.text.body.trim() : '';
        const m = text.match(/^login_([a-f0-9]{32})$/);
        if (!from || !m) {
          if (from) {
            await reply(
              from,
              'Чтобы войти в TAJ Bozor, откройте сайт app.tajbozor.pro и нажмите «Продолжить с WhatsApp».',
            );
          }
          continue;
        }

        const { data: row } = await db
          .from('telegram_login_requests')
          .select('nonce, created_at, wa_id')
          .eq('nonce', m[1])
          .eq('provider', 'whatsapp')
          .maybeSingle();
        if (!row || Date.now() - new Date(row.created_at).getTime() > TEN_MIN) {
          await reply(from, 'Ссылка устарела. Начните вход заново на сайте.');
          continue;
        }
        if (row.wa_id) {
          await reply(from, 'Вход уже подтверждён. Вернитесь на сайт TAJ Bozor.');
          continue;
        }
        await db
          .from('telegram_login_requests')
          .update({ wa_id: from, wa_name: names[from] ?? null })
          .eq('nonce', m[1]);
        await reply(from, 'Готово, вход подтверждён. Вернитесь на сайт TAJ Bozor: вы уже вошли.');
      }
    }
  }
  return new Response('ok');
});
