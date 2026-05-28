begin;

-- Allow anonymous (and keep authenticated) read of public timeline data.
-- Logged-in users still use existing visibility policies via authenticated role.

drop policy if exists whoeats_posts_select_public_anon on public.whoeats_posts;
create policy whoeats_posts_select_public_anon
on public.whoeats_posts
for select
to anon
using (deleted_at is null and visibility = 'public');

drop policy if exists whoeats_post_images_select_public_anon on public.whoeats_post_images;
create policy whoeats_post_images_select_public_anon
on public.whoeats_post_images
for select
to anon
using (
  deleted_at is null
  and exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and p.visibility = 'public'
  )
);

drop policy if exists whoeats_users_select_profile_anon on public.whoeats_users;
create policy whoeats_users_select_profile_anon
on public.whoeats_users
for select
to anon
using (deleted_at is null);

drop policy if exists whoeats_places_select_anon on public.whoeats_places;
create policy whoeats_places_select_anon
on public.whoeats_places
for select
to anon
using (true);

drop policy if exists whoeats_post_reactions_select_public_anon on public.whoeats_post_reactions;
create policy whoeats_post_reactions_select_public_anon
on public.whoeats_post_reactions
for select
to anon
using (
  exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and p.visibility = 'public'
  )
);

drop policy if exists whoeats_post_comments_select_public_anon on public.whoeats_post_comments;
create policy whoeats_post_comments_select_public_anon
on public.whoeats_post_comments
for select
to anon
using (
  deleted_at is null
  and exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and p.visibility = 'public'
  )
);

-- Mutual friends list (友達 = 相互フォロー only).
create or replace function public.get_my_friends()
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
  from public.whoeats_users u
  where u.deleted_at is null
    and auth.uid() is not null
    and public.is_friends(auth.uid(), u.id)
  order by u.name asc;
$$;

revoke all on function public.get_my_friends() from public;
grant execute on function public.get_my_friends() to authenticated;

-- Inbox from likes/comments on own posts (no notifications table in MVP).
create or replace function public.list_inbox_notifications(p_limit int default 50)
returns table (
  id text,
  message text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (select auth.uid() as uid),
  likes as (
    select
      ('like:' || r.post_id::text || ':' || r.user_id::text) as id,
      coalesce(u.name, u.user_code, 'ユーザー') || ' さんがあなたの投稿にいいねしました' as message,
      r.created_at
    from public.whoeats_post_reactions r
    join public.whoeats_posts p on p.id = r.post_id
    join public.whoeats_users u on u.id = r.user_id
    where p.user_id = (select uid from me)
      and r.user_id <> (select uid from me)
      and r.reaction_type = 'like'
      and p.deleted_at is null
  ),
  comments as (
    select
      ('comment:' || c.id::text) as id,
      coalesce(u.name, u.user_code, 'ユーザー') || ' さんがあなたの投稿にコメントしました' as message,
      c.created_at
    from public.whoeats_post_comments c
    join public.whoeats_posts p on p.id = c.post_id
    join public.whoeats_users u on u.id = c.user_id
    where p.user_id = (select uid from me)
      and c.user_id <> (select uid from me)
      and c.deleted_at is null
      and p.deleted_at is null
  )
  select * from (
    select * from likes
    union all
    select * from comments
  ) n
  order by created_at desc
  limit greatest(p_limit, 1);
$$;

revoke all on function public.list_inbox_notifications(int) from public;
grant execute on function public.list_inbox_notifications(int) to authenticated;

commit;
