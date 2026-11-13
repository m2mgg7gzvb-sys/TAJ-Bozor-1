-- Продавец: «Цена с торгом», «Телефон подтверждён», заметки к избранному,
-- напоминание о продлении за 3 дня.

alter table public.listings add column if not exists negotiable boolean not null default false;
alter table public.listings add column if not exists expiry_notified_at timestamptz;
alter table public.profiles add column if not exists phone_verified boolean not null default false;

-- Заметки к избранному (видит только владелец заметки).
create table if not exists public.favorite_notes (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  note text not null default '' check (char_length(note) <= 500),
  updated_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);
alter table public.favorite_notes enable row level security;

drop policy if exists "favorite_notes own select" on public.favorite_notes;
drop policy if exists "favorite_notes own insert" on public.favorite_notes;
drop policy if exists "favorite_notes own update" on public.favorite_notes;
drop policy if exists "favorite_notes own delete" on public.favorite_notes;
create policy "favorite_notes own select" on public.favorite_notes for select using (auth.uid() = user_id);
create policy "favorite_notes own insert" on public.favorite_notes for insert with check (auth.uid() = user_id);
create policy "favorite_notes own update" on public.favorite_notes for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "favorite_notes own delete" on public.favorite_notes for delete using (auth.uid() = user_id);

-- Напоминание владельцу, что объявление заканчивается через 3 дня.
-- Каждое объявление напоминается один раз (expiry_notified_at).
create or replace function public.notify_expiring_listings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  with due as (
    update public.listings l
       set expiry_notified_at = now()
     where l.status = 'active'
       and l.expires_at > now()
       and l.expires_at <= now() + interval '3 days'
       and l.expiry_notified_at is null
    returning l.id, l.user_id, l.title, l.expires_at
  ), ins as (
    insert into public.notifications (user_id, kind, title, body, listing_id, data)
    select d.user_id,
           'expiring',
           'Объявление скоро закончится',
           'Срок «' || d.title || '» истекает ' || to_char(d.expires_at at time zone 'Asia/Dushanbe', 'DD.MM.YYYY') || '. Продлите его в разделе «Объявления».',
           d.id,
           jsonb_build_object('listing_id', d.id)
      from due d
    returning 1
  )
  select count(*) into n from ins;
  return n;
end;
$$;

revoke all on function public.notify_expiring_listings() from public, anon, authenticated;

-- Ежедневно в 06:00 UTC (нужно расширение pg_cron).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('notify-expiring-listings', '0 6 * * *', 'select public.notify_expiring_listings()');
  end if;
end $$;
