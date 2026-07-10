begin;

-- Users who follow me but we are not mutual friends yet (I can "follow back" to become 友達).
create or replace function public.get_incoming_friend_requests()
returns table (
  user_id uuid,
  user_code text,
  name text,
  icon_path text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id as user_id,
    u.user_code,
    u.name,
    u.icon_path
  from public.whoeats_follows f
  join public.whoeats_users u on u.id = f.follower_id
  where f.following_id = auth.uid()
    and auth.uid() is not null
    and u.deleted_at is null
    and not public.is_friends(auth.uid(), u.id)
    and not public.is_blocked(auth.uid(), u.id)
  order by f.created_at desc;
$$;

revoke all on function public.get_incoming_friend_requests() from public;
grant execute on function public.get_incoming_friend_requests() to authenticated;

-- Users I follow who have not followed back yet (pending mutual).
create or replace function public.get_outgoing_pending_follows()
returns table (
  user_id uuid,
  user_code text,
  name text,
  icon_path text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id as user_id,
    u.user_code,
    u.name,
    u.icon_path
  from public.whoeats_follows f
  join public.whoeats_users u on u.id = f.following_id
  where f.follower_id = auth.uid()
    and auth.uid() is not null
    and u.deleted_at is null
    and not public.is_friends(auth.uid(), u.id)
    and not public.is_blocked(auth.uid(), u.id)
  order by f.created_at desc;
$$;

revoke all on function public.get_outgoing_pending_follows() from public;
grant execute on function public.get_outgoing_pending_follows() to authenticated;

commit;
