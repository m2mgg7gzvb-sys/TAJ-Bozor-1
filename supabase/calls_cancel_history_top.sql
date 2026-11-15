-- 1) Звонящий отменил вызов до ответа: банер у собеседника пропадает.
create or replace function public.cancel_call(p_channel text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.notifications
     set data = coalesce(data, '{}'::jsonb) || jsonb_build_object('status', 'cancelled')
   where kind = 'incoming_call'
     and data->>'channel' = p_channel
     and coalesce(data->>'status', 'ringing') = 'ringing'
     and created_at > now() - interval '10 minutes'
     and auth.uid() is not null
     and p_channel like '%' || left(replace(auth.uid()::text, '-', ''), 16) || '%';
$$;

revoke all on function public.cancel_call(text) from public, anon;
grant execute on function public.cancel_call(text) to authenticated;

-- Отменённый вызов не перезаписывается обратно в «ringing» при открытии банера.
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
     and data->>'channel' = p_channel
     and coalesce(data->>'status', '') <> 'cancelled';
$$;

revoke all on function public.set_call_status(text, text) from public, anon;
grant execute on function public.set_call_status(text, text) to authenticated;

-- 2) История звонка для звонков без переписки (принятых из баннера):
-- находим беседу, где участвуют оба собеседника и канал совпадает с их парой.
create or replace function public.call_conversation_id(p_channel text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
    from public.conversations c
   cross join lateral (
     select case when c.buyer_id = auth.uid() then c.seller_id else c.buyer_id end as other_id
   ) o
   where auth.uid() is not null
     and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
     and o.other_id is not null
     and p_channel = 'tb_' || (
       select string_agg(x, '_' order by x collate "C")
         from unnest(array[
           left(replace(auth.uid()::text, '-', ''), 16),
           left(replace(o.other_id::text, '-', ''), 16)
         ]) as x
     )
   limit 1;
$$;

revoke all on function public.call_conversation_id(text) from public, anon;
grant execute on function public.call_conversation_id(text) to authenticated;

-- 3) Заявки на продвижение TOP. Оплаты пока нет: заявка сохраняется со статусом 'pending'.
create table if not exists public.top_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  days int not null,
  price int not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'cancelled')),
  created_at timestamptz not null default now()
);

alter table public.top_orders enable row level security;

drop policy if exists "top_orders_own_select" on public.top_orders;
create policy "top_orders_own_select" on public.top_orders
  for select to authenticated using (user_id = auth.uid());

-- Сохраняет выбор: p_items = [{"listing_id": "...", "plan": 0..3}]. Цены считаются на сервере.
create or replace function public.request_top_orders(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  it jsonb;
  lid uuid;
  idx int;
  n int := 0;
  days_arr int[] := array[3, 7, 14, 30];
  price_arr int[] := array[5, 10, 18, 30];
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  for it in select * from jsonb_array_elements(p_items) loop
    lid := (it->>'listing_id')::uuid;
    idx := (it->>'plan')::int;
    if idx < 0 or idx > 3 then
      raise exception 'bad plan';
    end if;
    if not exists (
      select 1 from public.listings l
       where l.id = lid and l.user_id = auth.uid() and l.status = 'active'
    ) then
      raise exception 'listing not available';
    end if;
    -- Новая заявка на объявление заменяет прежнюю неоплаченную.
    update public.top_orders set status = 'cancelled'
     where listing_id = lid and user_id = auth.uid() and status = 'pending';
    insert into public.top_orders (user_id, listing_id, days, price)
    values (auth.uid(), lid, days_arr[idx + 1], price_arr[idx + 1]);
    n := n + 1;
  end loop;
  return n;
end;
$$;

revoke all on function public.request_top_orders(jsonb) from public, anon;
grant execute on function public.request_top_orders(jsonb) to authenticated;
