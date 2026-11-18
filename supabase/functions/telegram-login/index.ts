// Вход и регистрация через бота @tajbozor_tg_bot.
// start: создаёт запрос и возвращает nonce. Сайт открывает бота с ?start=login_<nonce>.
// check: когда пользователь поделился контактом в боте, создаёт или находит аккаунт и отдаёт token_hash.
// Секрет (Supabase → Edge Functions → Secrets): TELEGRAM_BOT_TOKEN.
import { createClient } from 'npm:@supabase/supabase-js@2';

const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const BOT_USERNAME = 'tajbozor_tg_bot';
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

function hex(buf: ArrayBuffer | Uint8Array): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// Секрет для вебхука бота: производный от токена, отдельный секрет не нужен.
async function webhookSecret(): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(BOT_TOKEN));
  return hex(d).slice(0, 32);
}

let webhookReady = false;
/// Указываем Telegram, куда присылать сообщения бота (один раз на запуск функции).
async function ensureWebhook() {
  if (webhookReady) return;
  const url = `${Deno.env.get('SUPABASE_URL')}/functions/v1/telegram-bot`;
  const r = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/setWebhook`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ url, secret_token: await webhookSecret(), allowed_updates: ['message'] }),
  });
  webhookReady = r.ok;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;

  if (body.action === 'start') {
    const nonce = hex(crypto.getRandomValues(new Uint8Array(16)));
    const { error } = await db.from('telegram_login_requests').insert({ nonce });
    if (error) return json({ error: 'db' }, 500);
    await ensureWebhook();
    return json({ nonce, bot: BOT_USERNAME });
  }

  if (body.action === 'check') {
    const nonce = String(body.nonce ?? '');
    if (!/^[a-f0-9]{32}$/.test(nonce)) return json({ error: 'bad nonce' }, 400);
    const { data: row } = await db
      .from('telegram_login_requests')
      .select('*')
      .eq('nonce', nonce)
      .maybeSingle();
    if (!row) return json({ error: 'not found' }, 404);
    if (Date.now() - new Date(row.created_at).getTime() > 10 * 60 * 1000) {
      await db.from('telegram_login_requests').delete().eq('nonce', nonce);
      return json({ error: 'expired' }, 410);
    }
    if (!row.telegram_id || !row.phone) return json({ pending: true });

    // Запрос одноразовый: после выдачи входа удаляем его
    await db.from('telegram_login_requests').delete().eq('nonce', nonce);

    const email = `tg${row.telegram_id}@telegram.tajbozor.local`;
    let link = await db.auth.admin.generateLink({ type: 'magiclink', email });
    if (link.error || !link.data?.properties?.hashed_token) {
      const created = await db.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: { telegram_id: String(row.telegram_id), name: row.first_name ?? '' },
      });
      if (created.error) return json({ error: 'create failed' }, 500);
      link = await db.auth.admin.generateLink({ type: 'magiclink', email });
    }
    const tokenHash = link.data?.properties?.hashed_token;
    const userId = link.data?.user?.id;
    if (!tokenHash) return json({ error: 'link failed' }, 500);

    // Номер из контакта Telegram подтверждён самим Telegram: сохраняем его как прямой номер
    if (userId) {
      await db.from('profiles').update({ phone: row.phone, phone_verified: true }).eq('id', userId);
    }
    return json({ token_hash: tokenHash });
  }

  return json({ error: 'action' }, 400);
});
