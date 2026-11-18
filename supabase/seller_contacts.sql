-- Контакты продавца для связи в WhatsApp и Telegram.
-- Чтение: сам пользователь или любой, если show_contacts = true.
create table if not exists public.seller_contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  whatsapp text,
  telegram text,
  show_contacts boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.seller_contacts enable row level security;

drop policy if exists "seller_contacts: читать свои или открытые" on public.seller_contacts;
create policy "seller_contacts: читать свои или открытые"
  on public.seller_contacts for select
  using (auth.uid() = user_id or show_contacts = true);

drop policy if exists "seller_contacts: писать свои" on public.seller_contacts;
create policy "seller_contacts: писать свои"
  on public.seller_contacts for insert
  with check (auth.uid() = user_id);

drop policy if exists "seller_contacts: менять свои" on public.seller_contacts;
create policy "seller_contacts: менять свои"
  on public.seller_contacts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
