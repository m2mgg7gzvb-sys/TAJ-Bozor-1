-- Уведомления администраторам (push через существующий push_on_notification):
--   обращения (callback_requests), жалобы (listing_reports), объявления на проверке (listings.status = 'moderation').
-- Не применено к продакшену: нужно подтверждение владельца.

create or replace function public.notify_admins(p_kind text, p_title text, p_body text, p_listing uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, kind, title, body, listing_id)
  select id, p_kind, p_title, p_body, p_listing
  from public.profiles
  where is_admin = true;
$$;

create or replace function public.admin_notify_callback()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_admins('admin_callback', 'Новое обращение', 'Просят перезвонить: ' || coalesce(new.phone, ''), new.listing_id);
  return new;
end;
$$;

create or replace function public.admin_notify_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_admins('admin_report', 'Новая жалоба', coalesce(new.reason, 'Жалоба на объявление'), new.listing_id);
  return new;
end;
$$;

create or replace function public.admin_notify_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'moderation' and (tg_op = 'INSERT' or old.status is distinct from 'moderation') then
    perform public.notify_admins('admin_moderation', 'Объявление на проверке', coalesce(new.title, 'Новое объявление'), new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists admin_callback_notify on public.callback_requests;
create trigger admin_callback_notify
  after insert on public.callback_requests
  for each row execute function public.admin_notify_callback();

drop trigger if exists admin_report_notify on public.listing_reports;
create trigger admin_report_notify
  after insert on public.listing_reports
  for each row execute function public.admin_notify_report();

drop trigger if exists admin_moderation_notify on public.listings;
create trigger admin_moderation_notify
  after insert or update of status on public.listings
  for each row execute function public.admin_notify_moderation();
