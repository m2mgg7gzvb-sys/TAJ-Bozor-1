-- Удаление аккаунта с восстановлением в течение 14 дней.
-- НЕ ПРИМЕНЕНО: применять только после подтверждения владельцем проекта.

-- 1. Новые поля.
alter table public.profiles add column if not exists deleted_at timestamptz;
alter table public.listings add column if not exists hidden_by_deletion boolean not null default false;

-- 2. Пользователь нажимает «Удалить аккаунт»: аккаунт и активные объявления скрываются.
create or replace function public.request_account_deletion()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  ts timestamptz := now();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  update public.profiles
     set deleted_at = ts
   where id = uid and deleted_at is null;

  update public.listings
     set status = 'hidden', hidden_by_deletion = true
   where user_id = uid and status = 'active';

  return ts;
end;
$$;

-- 3. Пользователь входит снова в течение 14 дней: аккаунт и объявления возвращаются.
create or replace function public.restore_account()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  d timestamptz;
begin
  if uid is null then
    return false;
  end if;

  select deleted_at into d from public.profiles where id = uid;
  if d is null then
    return false;
  end if;
  if d < now() - interval '14 days' then
    return false; -- срок вышел, аккаунт будет удалён задачей очистки
  end if;

  update public.profiles set deleted_at = null where id = uid;
  update public.listings
     set status = 'active', hidden_by_deletion = false
   where user_id = uid and hidden_by_deletion;

  return true;
end;
$$;

-- 4. Окончательное удаление через 14 дней. Вызывается ежедневной задачей pg_cron.
create or replace function public.purge_expired_accounts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id from public.profiles
     where deleted_at is not null and deleted_at < now() - interval '14 days'
  loop
    -- Сообщения и диалоги, где участвует пользователь или его объявления.
    delete from public.messages
     where sender_id = r.id
        or conversation_id in (
          select id from public.conversations
           where buyer_id = r.id or seller_id = r.id
              or listing_id in (select id from public.listings where user_id = r.id)
        );

    delete from public.conversation_members
     where user_id = r.id
        or conversation_id in (
          select id from public.conversations
           where buyer_id = r.id or seller_id = r.id
              or listing_id in (select id from public.listings where user_id = r.id)
        );

    delete from public.conversations
     where buyer_id = r.id or seller_id = r.id
        or listing_id in (select id from public.listings where user_id = r.id);

    -- Объявления и всё, что к ним привязано.
    delete from public.listing_images
     where listing_id in (select id from public.listings where user_id = r.id);
    delete from public.favorites
     where user_id = r.id
        or listing_id in (select id from public.listings where user_id = r.id);
    delete from public.listing_events
     where listing_id in (select id from public.listings where user_id = r.id);
    delete from public.callback_requests
     where listing_id in (select id from public.listings where user_id = r.id);
    delete from public.listing_reports
     where reporter_id = r.id
        or listing_id in (select id from public.listings where user_id = r.id);
    update public.admin_log
       set listing_id = null
     where listing_id in (select id from public.listings where user_id = r.id);
    delete from public.listings where user_id = r.id;

    -- Прочие данные пользователя.
    delete from public.notifications where user_id = r.id;
    delete from public.reviews where reviewed_id = r.id or author_id = r.id;
    delete from public.push_subscriptions where user_id = r.id;

    delete from public.profiles where id = r.id;
    delete from auth.users where id = r.id;

    n := n + 1;
  end loop;

  return n;
end;
$$;

-- 5. Права: пользователям — только свои две функции; очистку вызывает только задача.
revoke all on function public.request_account_deletion() from public;
revoke all on function public.restore_account() from public;
revoke all on function public.purge_expired_accounts() from public;
grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.restore_account() to authenticated;

-- 6. Ежедневная очистка в 03:00 UTC (нужно включить расширение pg_cron в Supabase).
-- create extension if not exists pg_cron with schema extensions;
-- select cron.schedule('purge-expired-accounts', '0 3 * * *', 'select public.purge_expired_accounts()');
