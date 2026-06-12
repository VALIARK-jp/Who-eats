begin;

-- Replace private (自分のみ) with near (友達の友達).
-- Visibility tiers: friends | near | public

update public.whoeats_users
set default_visibility = 'friends'
where default_visibility = 'private';

update public.whoeats_posts
set visibility = 'friends'
where visibility = 'private';

alter table public.whoeats_users
  drop constraint if exists users_default_visibility_check;

alter table public.whoeats_users
  drop constraint if exists whoeats_users_default_visibility_check;

alter table public.whoeats_users
  add constraint whoeats_users_default_visibility_check
  check (default_visibility in ('public', 'friends', 'near'));

alter table public.whoeats_posts
  drop constraint if exists posts_visibility_check;

alter table public.whoeats_posts
  drop constraint if exists whoeats_posts_visibility_check;

alter table public.whoeats_posts
  add constraint whoeats_posts_visibility_check
  check (visibility in ('public', 'friends', 'near'));

create or replace function public.can_view_post_visibility(p_author uuid, p_visibility text)
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
    and not public.is_blocked(auth.uid(), p_author)
    and (
      auth.uid() = p_author
      or p_visibility = 'public'
      or (p_visibility = 'friends' and public.is_friends(auth.uid(), p_author))
      or (
        p_visibility = 'near'
        and (
          public.is_friends(auth.uid(), p_author)
          or p_author in (select public.get_near_feed_user_ids())
        )
      )
    );
$$;

drop policy if exists posts_select_visible on public.whoeats_posts;
create policy posts_select_visible
on public.whoeats_posts
for select
to authenticated
using (
  deleted_at is null
  and public.can_view_post_visibility(user_id, visibility)
);

drop policy if exists post_images_select_by_post on public.whoeats_post_images;
create policy post_images_select_by_post
on public.whoeats_post_images
for select
to authenticated
using (
  deleted_at is null
  and exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and public.can_view_post_visibility(p.user_id, p.visibility)
  )
);

drop policy if exists post_comments_select_by_post on public.whoeats_post_comments;
create policy post_comments_select_by_post
on public.whoeats_post_comments
for select
to authenticated
using (
  deleted_at is null
  and exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and public.can_view_post_visibility(p.user_id, p.visibility)
  )
);

drop policy if exists post_comments_insert_on_visible_post on public.whoeats_post_comments;
create policy post_comments_insert_on_visible_post
on public.whoeats_post_comments
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and public.can_view_post_visibility(p.user_id, p.visibility)
  )
);

drop policy if exists post_reactions_select_by_post on public.whoeats_post_reactions;
create policy post_reactions_select_by_post
on public.whoeats_post_reactions
for select
to authenticated
using (
  exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and public.can_view_post_visibility(p.user_id, p.visibility)
  )
);

drop policy if exists post_reactions_insert_self on public.whoeats_post_reactions;
create policy post_reactions_insert_self
on public.whoeats_post_reactions
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and public.can_view_post_visibility(p.user_id, p.visibility)
  )
);

drop policy if exists whoeats_post_companions_select on public.whoeats_post_companions;
create policy whoeats_post_companions_select
on public.whoeats_post_companions
for select
to authenticated
using (
  exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and (
        public.can_view_post_visibility(p.user_id, p.visibility)
        or user_id = auth.uid()
      )
  )
);

commit;
