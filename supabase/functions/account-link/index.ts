// Связывание аккаунтов: один главный аккаунт (owner) и привязанный (linked).
// start:   вызывает главный аккаунт, создаёт одноразовый запрос привязки и отдаёт pending_id.
// confirm: вызывает аккаунт, который подтвердил владение своей почтой кодом, и создаёт связь.
// switch:  переключение между связанными аккаунтами, отдаёт token_hash для входа.
// links:   для вошедшего привязанного аккаунта отдаёт главный аккаунт (для окна выбора при входе).
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
    const { data: link } = await db
      .from('account_links')
      .select('id')
      .or(
        `and(owner_id.eq.${uid},linked_user_id.eq.${target}),and(owner_id.eq.${target},linked_user_id.eq.${uid})`,
      )
      .maybeSingle();
    if (!link) return json({ error: 'no link' }, 403);
    const { data: u } = await db.auth.admin.getUserById(target);
    const email = u?.user?.email;
    if (!email) return json({ error: 'no email' }, 409);
    const gen = await db.auth.admin.generateLink({ type: 'magiclink', email });
    const tokenHash = gen.data?.properties?.hashed_token;
    if (!tokenHash) return json({ error: 'link failed' }, 500);
    return json({ token_hash: tokenHash });
  }

  if (body.action === 'links') {
    const { data: l } = await db
      .from('account_links')
      .select('owner_id')
      .eq('linked_user_id', uid)
      .maybeSingle();
    if (!l) return json({ owner: null });
    const { data: u } = await db.auth.admin.getUserById(l.owner_id);
    const { data: p } = await db.from('profiles').select('name').eq('id', l.owner_id).maybeSingle();
    return json({
      owner: { id: l.owner_id, email: u?.user?.email ?? '', name: p?.name ?? '' },
    });
  }

  return json({ error: 'action' }, 400);
});
