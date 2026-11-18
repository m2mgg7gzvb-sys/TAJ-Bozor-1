// Вход и регистрация через WhatsApp.
// start: создаёт запрос и возвращает nonce и номер бота. Сайт открывает wa.me с текстом login_<nonce>.
// check: когда человек отправил этот текст в WhatsApp (вебхук whatsapp-webhook записал его номер), создаёт или находит аккаунт и отдаёт token_hash.
// Секреты (Supabase → Edge Functions → Secrets):
//   WHATSAPP_BUSINESS_NUMBER — номер бота без + (например 992000000000). Пока не задан, вход выключен.
import { createClient } from 'npm:@supabase/supabase-js@2';

const BUSINESS_NUMBER = (Deno.env.get('WHATSAPP_BUSINESS_NUMBER') ?? '').replace(/\D/g, '');
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;

  if (body.action === 'start') {
    if (!BUSINESS_NUMBER) return json({ error: 'not_configured' }, 503);
    const nonce = hex(crypto.getRandomValues(new Uint8Array(16)));
    const { error } = await db
      .from('telegram_login_requests')
      .insert({ nonce, provider: 'whatsapp' });
    if (error) return json({ error: 'db' }, 500);
    return json({ nonce, number: BUSINESS_NUMBER });
  }

  if (body.action === 'check') {
    const nonce = String(body.nonce ?? '');
    if (!/^[a-f0-9]{32}$/.test(nonce)) return json({ error: 'bad nonce' }, 400);
    const { data: row } = await db
      .from('telegram_login_requests')
      .select('*')
      .eq('nonce', nonce)
      .eq('provider', 'whatsapp')
      .maybeSingle();
    if (!row) return json({ error: 'not found' }, 404);
    if (Date.now() - new Date(row.created_at).getTime() > 10 * 60 * 1000) {
      await db.from('telegram_login_requests').delete().eq('nonce', nonce);
      return json({ error: 'expired' }, 410);
    }
    if (!row.wa_id) return json({ pending: true });

    // Запрос одноразовый
    await db.from('telegram_login_requests').delete().eq('nonce', nonce);

    const waId: string = row.wa_id;
    const email = `wa${waId}@whatsapp.tajbozor.local`;
    let link = await db.auth.admin.generateLink({ type: 'magiclink', email });
    if (link.error || !link.data?.properties?.hashed_token) {
      const created = await db.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: { whatsapp_id: waId, name: row.wa_name ?? '' },
      });
      if (created.error) return json({ error: 'create failed' }, 500);
      link = await db.auth.admin.generateLink({ type: 'magiclink', email });
    }
    const tokenHash = link.data?.properties?.hashed_token;
    const userId = link.data?.user?.id;
    if (!tokenHash) return json({ error: 'link failed' }, 500);

    if (userId) {
      // Номер подтверждён самим WhatsApp: сохраняем как номер WhatsApp в контактах продавца
      // (прямой номер в профиле не трогаем; показ контактов по умолчанию выключен)
      await db.from('seller_contacts').upsert(
        { user_id: userId, whatsapp: '+' + waId, updated_at: new Date().toISOString() },
        { onConflict: 'user_id' },
      );
      // Имя из WhatsApp: только если в профиле имени ещё нет (или стоит заглушка)
      if (row.wa_name) {
        await db
          .from('profiles')
          .update({ name: row.wa_name })
          .eq('id', userId)
          .in('name', ['', 'Пользователь']);
      }
    }
    return json({ token_hash: tokenHash });
  }

  return json({ error: 'action' }, 400);
});
