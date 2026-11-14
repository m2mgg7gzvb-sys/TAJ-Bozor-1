-- Статус входящего звонка: 'answered' — звонок состоялся, без статуса или 'declined' — пропущенный.
create or replace function public.set_call_status(p_channel text, p_status text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.notifications
     set data = coalesce(data, '{}'::jsonb) || jsonb_build_object('status', p_status)
   where user_id = auth.uid()
     and kind = 'incoming_call'
     and data->>'channel' = p_channel;
$$;

revoke all on function public.set_call_status(text, text) from public, anon;
grant execute on function public.set_call_status(text, text) to authenticated;
