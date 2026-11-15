-- Рассылка уведомлений всем аккаунтам, включая гостевые (только админ).
create or replace function public.admin_broadcast(p_title text, p_body text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) then
    raise exception 'not allowed';
  end if;
  if char_length(trim(coalesce(p_title, ''))) = 0 then
    raise exception 'empty title';
  end if;

  with ins as (
    insert into public.notifications (user_id, kind, title, body, listing_id, data)
    select p.id, 'broadcast', trim(p_title), trim(coalesce(p_body, '')), null, '{}'::jsonb
    from public.profiles p
    returning 1
  )
  select count(*) into n from ins;
  return n;
end;
$$;

revoke all on function public.admin_broadcast(text, text) from public, anon;
grant execute on function public.admin_broadcast(text, text) to authenticated;
