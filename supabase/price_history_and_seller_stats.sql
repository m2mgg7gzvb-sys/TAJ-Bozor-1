-- История цены объявления и статистика продавца.

create table if not exists public.listing_price_history (
  id bigint generated always as identity primary key,
  listing_id uuid not null references public.listings(id) on delete cascade,
  price numeric not null,
  changed_at timestamptz not null default now()
);
alter table public.listing_price_history enable row level security;
drop policy if exists "price_history_public_read" on public.listing_price_history;
create policy "price_history_public_read" on public.listing_price_history
  for select to anon, authenticated using (true);

create or replace function public.record_price_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.price is not null and (tg_op = 'INSERT' or new.price is distinct from old.price) then
    insert into public.listing_price_history (listing_id, price) values (new.id, new.price);
  end if;
  return new;
end;
$$;

drop trigger if exists price_history_on_listing on public.listings;
create trigger price_history_on_listing
  after insert or update of price on public.listings
  for each row execute function public.record_price_history();

-- Статистика по своим объявлениям: просмотры, звонки, добавления в избранное.
create or replace function public.my_listing_stats()
returns table (listing_id uuid, title text, views integer, calls bigint, favorites bigint)
language sql
stable
security definer
set search_path = public
as $$
  select l.id, l.title, l.views,
         (select count(*) from public.listing_events e where e.listing_id = l.id and e.kind = 'call'),
         (select count(*) from public.favorites f where f.listing_id = l.id)
  from public.listings l
  where l.user_id = auth.uid()
  order by l.created_at desc;
$$;

revoke all on function public.my_listing_stats() from public, anon;
grant execute on function public.my_listing_stats() to authenticated;
