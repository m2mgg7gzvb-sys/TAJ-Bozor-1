-- Уведомление подписчикам продавца, когда объявление становится активным
-- (при создании без модерации или после одобрения). Уже применено в базе.
create or replace function public.notify_seller_followers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from 'active' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status is not distinct from 'active' then
    return new;
  end if;
  insert into public.notifications (user_id, kind, title, body, listing_id, data)
  select f.follower_id, 'seller_new', 'Новое объявление от продавца', new.title, new.id,
         jsonb_build_object('seller_id', new.user_id)
  from public.seller_follows f
  where f.seller_id = new.user_id;
  return new;
end;
$$;

drop trigger if exists seller_follow_notify on public.listings;
create trigger seller_follow_notify
  after insert or update of status on public.listings
  for each row execute function public.notify_seller_followers();
