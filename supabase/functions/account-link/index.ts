// Связывание аккаунтов: один главный аккаунт (owner) и привязанный (linked).
// start:   вызывает главный аккаунт, создаёт одноразовый запрос привязки и отдаёт pending_id.
// confirm: вызывает аккаунт, который подтвердил владение своей почтой кодом, и создаёт связь.
// switch:  переключение между связанными аккаунтами, отдаёт token_hash для входа.
// links:   отдаёт связанные аккаунты (привязка и Telegram) для окна выбора при входе.
import { createClient } from 'npm:@supabase/supabase-js@2';

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

const TEN_MINUTES = 10 * 60 * 1000;
const UUID = /^[0-9a-f-]{36}$/i;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'content-type': 'application/json' },
  });
}

async function callerId(req: Request): Promise<string | null> {
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data } = await db.auth.getUser(token);
  return data?.user?.id ?? null;
}


async function emailOf(id: string): Promise<string> {
  const { data } = await db.auth.admin.getUserById(id);
  return data?.user?.email ?? '';
}

async function findIdByEmail(email: string): Promise<string | null> {
  for (let page = 1; page <= 20; page++) {
    const { data } = await db.auth.admin.listUsers({ page, perPage: 1000 });
    const users = data?.users ?? [];
    const found = users.find((u) => u.email === email);
    if (found) return found.id;
    if (users.length < 1000) break;
  }
  return null;
}

/// Аккаунты, связанные с этим: привязанные через «Привязать аккаунт» и
/// аккаунт Telegram (отдельный tg-аккаунт и главный аккаунт, к которому привязан Telegram).
async function alternativesOf(uid: string): Promise<string[]> {
  const ids = new Set<string>();
  const { data: asOwner } = await db.from('account_links').select('linked_user_id').eq('owner_id', uid);
  for (const r of asOwner ?? []) ids.add(r.linked_user_id as string);
  const { data: asLinked } = await db.from('account_links').select('owner_id').eq('linked_user_id', uid);
  for (const r of asLinked ?? []) ids.add(r.owner_id as string);

  const myEmail = await emailOf(uid);
  const tg = myEmail.match(/^tg(\d+)@telegram\.tajbozor\.local$/);
  if (tg) {
    // Я — отдельный tg-аккаунт: ищем главный аккаунт, к которому привязан этот Telegram
    const { data: link } = await db.from('telegram_links').select('user_id').eq('telegram_id', tg[1]).maybeSingle();
    if (link && link.user_id !== uid) ids.add(link.user_id as string);
  } else {
    // Я — главный аккаунт: ищем отдельный tg-аккаунт моих Telegram-привязок
    const { data: mine } = await db.from('telegram_links').select('telegram_id').eq('user_id', uid);
    for (const r of mine ?? []) {
      const tgId = await findIdByEmail(`tg${r.telegram_id}@telegram.tajbozor.local`);
      if (tgId && tgId !== uid) ids.add(tgId);
    }
  }
  return [...ids];
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const uid = await callerId(req);
  if (!uid) return json({ error: 'unauthorized' }, 401);

  const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;

  if (body.action === 'start') {
    await db.from('account_link_pending').delete().eq('owner_id', uid);
    const { data, error } = await db
      .from('account_link_pending')
      .insert({ owner_id: uid })
      .select('id')
      .single();
    if (error) return json({ error: 'db' }, 500);
    return json({ pending_id: data.id });
  }

  if (body.action === 'confirm') {
    const pendingId = String(body.pending_id ?? '');
    if (!UUID.test(pendingId)) return json({ error: 'bad id' }, 400);
    const { data: row } = await db
      .from('account_link_pending')
      .select('owner_id, created_at')
      .eq('id', pendingId)
      .maybeSingle();
    if (!row) return json({ error: 'not found' }, 404);
    await db.from('account_link_pending').delete().eq('id', pendingId);
    if (Date.now() - new Date(row.created_at).getTime() > TEN_MINUTES) return json({ error: 'expired' }, 410);
    if (row.owner_id === uid) return json({ error: 'self' }, 400);

    // Цепочки не делаем: главный аккаунт не может быть привязанным, а привязанный — главным.
    const { data: ownerLinked } = await db
      .from('account_links')
      .select('id')
      .eq('linked_user_id', row.owner_id)
      .maybeSingle();
    if (ownerLinked) return json({ error: 'owner_linked' }, 409);
    const { data: meOwner } = await db.from('account_links').select('id').eq('owner_id', uid).limit(1);
    if (meOwner && meOwner.length > 0) return json({ error: 'owns_links' }, 409);

    const { error } = await db
      .from('account_links')
      .insert({ owner_id: row.owner_id, linked_user_id: uid });
    if (error) return json({ error: 'taken' }, 409);
    return json({ linked: true });
  }

  if (body.action === 'switch') {
    const target = String(body.target_user_id ?? '');
    if (!UUID.test(target)) return json({ error: 'bad id' }, 400);
    if (!(await alternativesOf(uid)).includes(target)) return json({ error: 'no link' }, 403);
    const email = await emailOf(target);
    if (!email) return json({ error: 'no email' }, 409);
    const gen = await db.auth.admin.generateLink({ type: 'magiclink', email });
    const tokenHash = gen.data?.properties?.hashed_token;
    if (!tokenHash) return json({ error: 'link failed' }, 500);
    return json({ token_hash: tokenHash });
  }

  if (body.action === 'links') {
    const ids = await alternativesOf(uid);
    if (ids.length === 0) return json({ accounts: [] });
    // Я — привязанный аккаунт (вошёл как «доп»): главный — другой. Иначе я главный.
    const { data: asLinkedSide } = await db.from('account_links').select('id').eq('linked_user_id', uid).maybeSingle();
    const myEmail = await emailOf(uid);
    const linkedSide = !!asLinkedSide || TG_EMAIL.test(myEmail);
    const all = [uid, ...ids];
    const { data: ps } = await db.from('profiles').select('id, name, avatar_url, public_id').in('id', all);
    const byId = Object.fromEntries((ps ?? []).map((p) => [p.id as string, p]));
    const accounts = all.map((id) => ({
      id,
      name: (byId[id]?.name as string | null) ?? '',
      avatar_url: (byId[id]?.avatar_url as string | null) ?? null,
      public_id: (byId[id]?.public_id as string | null) ?? null,
      role: (id === uid) === linkedSide ? 'Привязка' : 'Основной',
    }));
    return json({ accounts, me: uid });
  }

  return json({ error: 'action' }, 400);
});
