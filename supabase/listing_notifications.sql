-- Уведомления по объявлениям (уже применены в базе):
--  * снижение цены: избранным и тем, чей сохранённый поиск подходит;
--  * объявление продано / снято / срок истёк: избранным; владельцу — при истечении срока.
-- Уведомления пишутся в notifications, пуш уходит триггером push_on_notification.

create or replace function public.notify_price_drop()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from 'active' then
    return new;
  end if;

  insert into public.notifications (user_id, kind, title, body, listing_id, data)
  select f.user_id,
         'price_drop',
         'Цена снижена',
         new.title || ': ' || old.price::text || ' → ' || new.price::text || ' TJS',
         new.id,
         jsonb_build_object('old_price', old.price, 'new_price', new.price)
  from public.favorites f
  where f.listing_id = new.id
    and f.user_id is distinct from new.user_id;

  insert into public.notifications (user_id, kind, title, body, listing_id, data)
  select s.user_id,
         'price_drop_search',
         'Цена снижена по вашему поиску: ' || s.title,
         new.title || ': ' || old.price::text || ' → ' || new.price::text || ' TJS',
         new.id,
         jsonb_build_object('saved_search_id', s.id, 'old_price', old.price, 'new_price', new.price)
  from public.saved_searches s
  where s.user_id is distinct from new.user_id
    and (s.category_id is null or s.category_id = new.category_id)
    and (s.subcategory_id is null or s.subcategory_id = new.subcategory_id)
    and (s.brand is null or lower(new.details->>'brand') = lower(s.brand))
    and (s.model is null or lower(new.details->>'model') = lower(s.model))
    and (s.price_min is null or new.price >= s.price_min)
    and (s.price_max is null or new.price <= s.price_max)
    and (s.query is null or new.title ilike '%' || s.query || '%'
                         or coalesce(new.description, '') ilike '%' || s.query || '%')
    and not exists (
      select 1 from public.favorites f
      where f.listing_id = new.id and f.user_id = s.user_id
    );
  return new;
end;
$$;

create or replace function public.notify_listing_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;
  if old.status is distinct from 'active' then
    return new;
  end if;
  if new.status not in ('sold', 'hidden', 'expired') then
    return new;
  end if;

  insert into public.notifications (user_id, kind, title, body, listing_id, data)
  select f.user_id,
         'favorite_status',
         case new.status
           when 'sold' then 'Объявление продано'
           when 'expired' then 'Срок объявления истёк'
           else 'Объявление снято с публикации'
         end,
         new.title,
         new.id,
         jsonb_build_object('status', new.status, 'listing_id', new.id)
  from public.favorites f
  where f.listing_id = new.id
    and f.user_id is distinct from new.user_id;

  if new.status = 'expired' then
    insert into public.notifications (user_id, kind, title, body, listing_id, data)
    values (
      new.user_id,
      'expired',
      'Срок объявления истёк',
      new.title || '. Продлите его в разделе «Объявления», чтобы оно снова было в поиске.',
      new.id,
      jsonb_build_object('listing_id', new.id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists listing_status_notify on public.listings;
create trigger listing_status_notify
  after update of status on public.listings
  for each row execute function public.notify_listing_status_change();
