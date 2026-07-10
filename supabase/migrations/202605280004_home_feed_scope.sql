begin;

-- 2-hop: 友達のフォロー先（自分・直接の友達以外）
create or replace function public.get_near_feed_user_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select distinct f2.following_id
  from public.whoeats_follows f1
  join public.whoeats_follows f2 on f2.follower_id = f1.following_id
  where auth.uid() is not null
    and f1.follower_id = auth.uid()
    and f2.following_id <> auth.uid()
    and not public.is_friends(auth.uid(), f2.following_id)
    and not public.is_blocked(auth.uid(), f2.following_id);
$$;

revoke all on function public.get_near_feed_user_ids() from public;
grant execute on function public.get_near_feed_user_ids() to authenticated;

commit;
