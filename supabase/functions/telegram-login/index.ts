// Вход через Telegram Login Widget.
// Клиент присылает данные, которые вернул Telegram (id, first_name, username, auth_date, hash).
// Функция проверяет подпись бот-токеном, находит или создаёт пользователя и отдаёт token_hash
// для обычного входа по magic link на клиенте.
// Секрет (Supabase → Edge Functions → Secrets): TELEGRAM_BOT_TOKEN. SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY даёт сам Supabase.
import { createClient } from 'npm:@supabase/supabase-js@2';

const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, authorization, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'content-type': 'application/json' },
  });
}

function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// Проверка подписи Telegram: secret = SHA256(токен), hash = HMAC_SHA256(secret, строка_проверки).
async function verifyTelegram(data: Record<string, string>): Promise<boolean> {
  const { hash, ...rest } = data;
  if (!hash) return false;
  const checkString = Object.keys(rest)
    .sort()
    .map((k) => `${k}=${rest[k]}`)
    .join('\n');
  const enc = new TextEncoder();
  const secret = await crypto.subtle.digest('SHA-256', enc.encode(BOT_TOKEN));
  const key = await crypto.subtle.importKey(
    'raw', secret, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(checkString));
  if (toHex(sig) !== hash) return false;
  // Защита от старых данных: вход принимается только в течение суток
  const authDate = Number(data.auth_date);
  return Number.isFinite(authDate) && Date.now() / 1000 - authDate < 86400;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad json' }, 400);
  }
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(body)) {
    if (v !== null && v !== undefined) data[k] = String(v);
  }
  if (!data.id) return json({ error: 'no id' }, 400);

  if (!(await verifyTelegram(data))) return json({ error: 'bad signature' }, 401);

  // Пользователь Supabase привязан к Telegram-id через служебную почту
  const email = `tg${data.id}@telegram.tajbozor.local`;
  let linkRes = await db.auth.admin.generateLink({ type: 'magiclink', email });
  if (linkRes.error || !linkRes.data?.properties?.hashed_token) {
    const created = await db.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: { telegram_id: data.id, name: data.first_name ?? '' },
    });
    if (created.error) return json({ error: 'create failed' }, 500);
    linkRes = await db.auth.admin.generateLink({ type: 'magiclink', email });
  }
  const tokenHash = linkRes.data?.properties?.hashed_token;
  if (!tokenHash) return json({ error: 'link failed' }, 500);

  return json({ token_hash: tokenHash, email, username: data.username ?? null });
});
