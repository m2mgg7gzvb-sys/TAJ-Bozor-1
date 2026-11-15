-- Статус звонка со стороны собеседника: 'ringing' — приглашение показано у него, 'answered', 'declined'.
-- set_call_status (supabase/call_status.sql) пишет статус в уведомление собеседника.

-- Звонящий узнаёт, дошёл ли вызов (гудки у собеседника) и не отклонил ли он звонок.
create or replace function public.call_peer_status(p_channel text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select n.data->>'status'
    from public.notifications n
   where n.kind = 'incoming_call'
     and n.data->>'channel' = p_channel
     and n.created_at > now() - interval '10 minutes'
   order by n.created_at desc
   limit 1;
$$;

revoke all on function public.call_peer_status(text) from public, anon;
grant execute on function public.call_peer_status(text) to authenticated;
