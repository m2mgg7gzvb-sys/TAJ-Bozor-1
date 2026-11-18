// Вебхук бота @tajbozor_tg_bot.
// /start login_<nonce> — просит поделиться контактом. Контакт подтверждает вход на сайте.
// Секрет: TELEGRAM_BOT_TOKEN. Заголовок secret_token проверяем производным секретом от токена.
import { createClient } from 'npm:@supabase/supabase-js@2';

const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const TEN_MIN = 10 * 60 * 1000;
const shareKeyboard = {
  reply_markup: {
    keyboard: [[{ text: 'Поделиться контактом', request_contact: true }]],
    resize_keyboard: true,
    one_time_keyboard: true,
  },
};
const removeKeyboard = { reply_markup: { remove_keyboard: true } };

async function webhookSecret(): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(BOT_TOKEN));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
}

async function send(chatId: number, text: string, extra: Record<string, unknown> = {}) {
  await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, ...extra }),
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('ok');
  if (req.headers.get('x-telegram-bot-api-secret-token') !== await webhookSecret()) {
    return new Response('forbidden', { status: 403 });
  }
  const upd = await req.json().catch(() => null);
  const msg = upd?.message;
  if (!msg?.from) return new Response('ok');
  const chatId: number = msg.chat.id;
  const from = msg.from;

  // Пользователь отправил контакт
  if (msg.contact) {
    if (msg.contact.user_id !== from.id) {
      await send(chatId, 'Отправьте свой контакт кнопкой под полем ввода.', shareKeyboard);
      return new Response('ok');
    }
    const phone = '+' + String(msg.contact.phone_number).replace(/\D/g, '');
    const { data: row } = await db
      .from('telegram_login_requests')
      .select('nonce, created_at')
      .eq('telegram_id', from.id)
      .is('phone', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (!row || Date.now() - new Date(row.created_at).getTime() > TEN_MIN) {
      await send(chatId, 'Ссылка для входа устарела. Начните вход заново на сайте.', removeKeyboard);
      return new Response('ok');
    }
    await db.from('telegram_login_requests').update({ phone }).eq('nonce', row.nonce);
    await send(chatId, 'Готово. Вернитесь в приложение TAJ Bozor: вход выполнится автоматически.', removeKeyboard);
    return new Response('ok');
  }

  // Пользователь нажал Start по ссылке с сайта
  const m = typeof msg.text === 'string' ? msg.text.match(/^\/start login_([a-f0-9]{32})$/) : null;
  if (m) {
    const { data: row } = await db
      .from('telegram_login_requests')
      .select('nonce, created_at')
      .eq('nonce', m[1])
      .maybeSingle();
    if (!row || Date.now() - new Date(row.created_at).getTime() > TEN_MIN) {
      await send(chatId, 'Ссылка устарела. Начните вход заново на сайте.');
      return new Response('ok');
    }
    await db
      .from('telegram_login_requests')
      .update({ telegram_id: from.id, first_name: from.first_name ?? null, username: from.username ?? null })
      .eq('nonce', m[1]);
    await send(chatId, 'Чтобы войти в TAJ Bozor, поделитесь своим контактом. Нажмите кнопку ниже.', shareKeyboard);
    return new Response('ok');
  }

  await send(chatId, 'Чтобы войти в TAJ Bozor, откройте сайт app.tajbozor.pro и нажмите «Продолжить с Telegram».');
  return new Response('ok');
});
