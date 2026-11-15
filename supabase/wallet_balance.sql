-- Внутренний баланс пользователя в TJS. Сумма только по проведённым записям (status = 'done').
create table if not exists public.wallet_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  amount int not null,
  kind text not null check (kind in ('topup', 'top_purchase', 'adjustment')),
  status text not null default 'done' check (status in ('pending', 'done', 'cancelled')),
  note text,
  created_at timestamptz not null default now()
);

alter table public.wallet_entries enable row level security;

drop policy if exists "wallet_entries_own_select" on public.wallet_entries;
create policy "wallet_entries_own_select" on public.wallet_entries
  for select to authenticated using (user_id = auth.uid());

alter table public.listings add column if not exists top_until timestamptz;

create or replace function public.get_balance()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(amount), 0)::int
    from public.wallet_entries
   where user_id = auth.uid() and status = 'done';
$$;

revoke all on function public.get_balance() from public, anon;
grant execute on function public.get_balance() to authenticated;

-- Заявка на пополнение. Деньги появятся на балансе после подтверждения (платёж или админ).
create or replace function public.request_topup(p_amount int)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  eid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_amount < 10 or p_amount > 5000 then
    raise exception 'bad amount';
  end if;
  insert into public.wallet_entries (user_id, amount, kind, status, note)
  values (auth.uid(), p_amount, 'topup', 'pending', 'Ожидает оплаты')
  returning id into eid;
  return eid;
end;
$$;

revoke all on function public.request_topup(int) from public, anon;
grant execute on function public.request_topup(int) to authenticated;

-- Подтверждение пополнения: пока вручную админом, позже — из платёжного провайдера.
create or replace function public.admin_confirm_topup(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true) then
    raise exception 'admin only';
  end if;
  update public.wallet_entries
     set status = 'done', note = 'Пополнение подтверждено'
   where id = p_id and kind = 'topup' and status = 'pending';
end;
$$;

revoke all on function public.admin_confirm_topup(uuid) from public, anon;
grant execute on function public.admin_confirm_topup(uuid) to authenticated;

-- Покупка TOP с баланса. Всё или ничего: при нехватке денег ничего не списывается.
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
  total int := 0;
  bal int;
  title text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- Проверяем сумму и баланс до любых записей.
  for it in select * from jsonb_array_elements(p_items) loop
    idx := (it->>'plan')::int;
    if idx < 0 or idx > 3 then
      raise exception 'bad plan';
    end if;
    total := total + price_arr[idx + 1];
  end loop;
  select coalesce(sum(amount), 0)::int into bal
    from public.wallet_entries where user_id = auth.uid() and status = 'done';
  if bal < total then
    raise exception 'insufficient balance';
  end if;

  for it in select * from jsonb_array_elements(p_items) loop
    lid := (it->>'listing_id')::uuid;
    idx := (it->>'plan')::int;
    select l.title into title from public.listings l
     where l.id = lid and l.user_id = auth.uid() and l.status = 'active';
    if title is null then
      raise exception 'listing not available';
    end if;
    update public.top_orders set status = 'cancelled'
     where listing_id = lid and user_id = auth.uid() and status = 'pending';
    insert into public.top_orders (user_id, listing_id, days, price, status)
    values (auth.uid(), lid, days_arr[idx + 1], price_arr[idx + 1], 'paid');
    insert into public.wallet_entries (user_id, amount, kind, status, note)
    values (auth.uid(), -price_arr[idx + 1], 'top_purchase', 'done', 'TOP: ' || title);
    update public.listings
       set top_until = greatest(coalesce(top_until, now()), now()) + make_interval(days => days_arr[idx + 1])
     where id = lid;
    n := n + 1;
  end loop;
  return n;
end;
$$;

revoke all on function public.request_top_orders(jsonb) from public, anon;
grant execute on function public.request_top_orders(jsonb) to authenticated;
