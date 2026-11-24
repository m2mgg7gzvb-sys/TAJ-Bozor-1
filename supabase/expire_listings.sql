-- Истечение срока объявлений: активные объявления с прошедшим expires_at переходят в статус «expired».
-- Без этого кнопка «Продлить» для истёкших не появляется, а счётчик «Срок истёк» не срабатывает.

create or replace function public.expire_listings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  update public.listings
     set status = 'expired'
   where status = 'active'
     and expires_at is not null
     and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.expire_listings() from public, anon, authenticated;

-- Каждый час (нужно включить pg_cron в Supabase).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('expire-listings', '0 * * * *', 'select public.expire_listings()');
  end if;
end $$;
