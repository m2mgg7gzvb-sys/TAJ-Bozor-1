-- Подписка на продавца, черновик объявления и поднятие объявления в топ.

-- 1. Подписка: подписчик получает уведомление о новом объявлении продавца.
create table if not exists public.seller_follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, seller_id)
);
alter table public.seller_follows enable row level security;
drop policy if exists "follows_own_select" on public.seller_follows;
drop policy if exists "follows_own_insert" on public.seller_follows;
drop policy if exists "follows_own_delete" on public.seller_follows;
create policy "follows_own_select" on public.seller_follows for select to authenticated using (follower_id = auth.uid());
create policy "follows_own_insert" on public.seller_follows for insert to authenticated with check (follower_id = auth.uid());
create policy "follows_own_delete" on public.seller_follows for delete to authenticated using (follower_id = auth.uid());

create or replace function public.notify_seller_followers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from 'active' then
    return new;
  end if;
  insert into public.notifications (user_id, kind, title, body, listing_id, data)
  select f.follower_id, 'seller_new', 'Новое объявление от продавца', new.title, new.id,
         jsonb_build_object('seller_id', new.user_id)
  from public.seller_follows f
  where f.seller_id = new.user_id;
  return new;
end;
$$;

drop trigger if exists seller_follow_notify on public.listings;
create trigger seller_follow_notify
  after insert on public.listings
  for each row execute function public.notify_seller_followers();

-- 2. Черновик объявления (один на пользователя).
create table if not exists public.listing_drafts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.listing_drafts enable row level security;
drop policy if exists "drafts_own" on public.listing_drafts;
create policy "drafts_own" on public.listing_drafts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3. Поднятие в топ: не чаще раза в 24 часа. Поднятое объявление выводится первым в сортировке «Выгодные».
alter table public.listings add column if not exists bumped_at timestamptz;

create or replace function public.bump_listing(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  last_at timestamptz;
begin
  select coalesce(bumped_at, created_at) into last_at
  from public.listings where id = p_id and user_id = auth.uid();
  if last_at is null then
    raise exception 'not_owner';
  end if;
  if last_at > now() - interval '24 hours' then
    raise exception 'too_soon';
  end if;
  update public.listings set bumped_at = now() where id = p_id;
  return now();
end;
$$;

revoke all on function public.bump_listing(uuid) from public, anon;
grant execute on function public.bump_listing(uuid) to authenticated;
