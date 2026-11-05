-- Push-уведомления: таблица подписок устройств и доступ только к своим подпискам.
-- Выполнять в SQL Editor Supabase целиком, один раз.

create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz default now()
);

alter table push_subscriptions enable row level security;

create policy "push_own_select" on push_subscriptions
  for select to authenticated using (user_id = auth.uid());

create policy "push_own_insert" on push_subscriptions
  for insert to authenticated with check (user_id = auth.uid());

create policy "push_own_update" on push_subscriptions
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "push_own_delete" on push_subscriptions
  for delete to authenticated using (user_id = auth.uid());
