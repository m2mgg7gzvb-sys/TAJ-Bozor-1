-- Просмотр объявления засчитывается один раз на человека: сколько бы раз он ни открыл объявление.

create table if not exists public.listing_viewers (
  listing_id uuid not null references public.listings(id) on delete cascade,
  viewer_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (listing_id, viewer_id)
);

-- Без политик: доступ только через функцию ниже.
alter table public.listing_viewers enable row level security;

create or replace function public.bump_listing_view(lid uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  added integer := 0;
  me uuid := auth.uid();
begin
  if me is not null then
    insert into public.listing_viewers (listing_id, viewer_id)
    select l.id, me
      from public.listings l
     where l.id = lid
       and l.status = 'active'
       and l.user_id is distinct from me
    on conflict do nothing;
    get diagnostics added = row_count;
    if added > 0 then
      update public.listings set views = views + 1 where id = lid;
    end if;
  end if;
  select views into n from public.listings where id = lid;
  return coalesce(n, 0);
end;
$$;
