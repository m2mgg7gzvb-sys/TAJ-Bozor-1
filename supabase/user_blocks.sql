-- Блокировка пользователей: объявления заблокированного скрыты из поиска.
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.user_blocks enable row level security;

drop policy if exists "user_blocks own select" on public.user_blocks;
drop policy if exists "user_blocks own insert" on public.user_blocks;
drop policy if exists "user_blocks own delete" on public.user_blocks;
create policy "user_blocks own select" on public.user_blocks for select using (auth.uid() = blocker_id);
create policy "user_blocks own insert" on public.user_blocks for insert with check (auth.uid() = blocker_id);
create policy "user_blocks own delete" on public.user_blocks for delete using (auth.uid() = blocker_id);
