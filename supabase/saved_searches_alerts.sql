-- Сохранённые поиски на всех устройствах и уведомления:
--  * о новом объявлении, подходящем под сохранённый поиск;
--  * о снижении цены у объявления из избранного.
-- Уведомления пишутся в notifications, а push уходит существующим триггером push_on_notification.

create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  key text not null,
  title text not null,
  category_id integer,
  subcategory_id bigint,
  brand text,
  model text,
  price_min numeric,
  price_max numeric,
  query text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, key)
);

alter table public.saved_searches enable row level security;

drop policy if exists "saved_searches_own_select" on public.saved_searches;
drop policy if exists "saved_searches_own_insert" on public.saved_searches;
drop policy if exists "saved_searches_own_delete" on public.saved_searches;
create policy "saved_searches_own_select" on public.saved_searches
  for select to authenticated using (user_id = auth.uid());
create policy "saved_searches_own_insert" on public.saved_searches
  for insert to authenticated with check (user_id = auth.uid());
create policy "saved_searches_own_delete" on public.saved_searches
  for delete to authenticated using (user_id = auth.uid());

-- Новое объявление → уведомления тем, чей сохранённый поиск под него подходит.
create or replace function public.notify_saved_search_matches()
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
  select s.user_id,
         'saved_search',
         'Новое по вашему поиску: ' || s.title,
         new.title || case when new.price is not null then ' · ' || new.price::text || ' TJS' else '' end,
         new.id,
         jsonb_build_object('saved_search_id', s.id)
  from public.saved_searches s
  where s.user_id is distinct from new.user_id
    and (s.category_id is null or s.category_id = new.category_id)
    and (s.subcategory_id is null or s.subcategory_id = new.subcategory_id)
    and (s.brand is null or lower(new.details->>'brand') = lower(s.brand))
    and (s.model is null or lower(new.details->>'model') = lower(s.model))
    and (s.price_min is null or new.price >= s.price_min)
    and (s.price_max is null or new.price <= s.price_max)
    and (s.query is null or new.title ilike '%' || s.query || '%'
                         or coalesce(new.description, '') ilike '%' || s.query || '%');
  return new;
end;
$$;

drop trigger if exists saved_search_match_on_listing on public.listings;
create trigger saved_search_match_on_listing
  after insert on public.listings
  for each row execute function public.notify_saved_search_matches();

-- Снижение цены → уведомление всем, кто добавил объявление в избранное.
create or replace function public.notify_price_drop()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, kind, title, body, listing_id, data)
  select f.user_id,
         'price_drop',
         'Цена снижена',
         new.title || ': ' || old.price::text || ' → ' || new.price::text || ' TJS',
         new.id,
         jsonb_build_object('old_price', old.price, 'new_price', new.price)
  from public.favorites f
  where f.listing_id = new.id;
  return new;
end;
$$;

drop trigger if exists price_drop_on_listing on public.listings;
create trigger price_drop_on_listing
  after update of price on public.listings
  for each row
  when (new.price is not null and old.price is not null and new.price < old.price)
  execute function public.notify_price_drop();
