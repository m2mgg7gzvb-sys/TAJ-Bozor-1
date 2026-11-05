-- Триггеры push-уведомлений: при вставке в notifications и messages вызывают Edge Function send-push.
-- Уже применено в проекте. Нужно расширение pg_net.
create extension if not exists pg_net with schema extensions;

create or replace function public.send_push_webhook()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform net.http_post(
    url := 'https://oseshgeughyegfnuolpx.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <ANON_KEY>'
    ),
    body := jsonb_build_object('table', TG_TABLE_NAME, 'record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

drop trigger if exists push_on_notification on public.notifications;
create trigger push_on_notification
  after insert on public.notifications
  for each row execute function public.send_push_webhook();

drop trigger if exists push_on_message on public.messages;
create trigger push_on_message
  after insert on public.messages
  for each row execute function public.send_push_webhook();
