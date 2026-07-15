begin;

-- Prod repair: bootstrap-created whoeats_* tables had policies but RLS was never enabled.
-- Some tables (follows/blocks) also lacked policies on the whoeats_* names.
-- Idempotent: safe to re-run.

-- =========================
-- Enable RLS on core tables
-- =========================

alter table if exists public.whoeats_users enable row level security;
alter table if exists public.whoeats_follows enable row level security;
alter table if exists public.whoeats_blocks enable row level security;
alter table if exists public.whoeats_places enable row level security;
alter table if exists public.whoeats_posts enable row level security;
alter table if exists public.whoeats_post_images enable row level security;
alter table if exists public.whoeats_post_comments enable row level security;
alter table if exists public.whoeats_post_reactions enable row level security;
alter table if exists public.whoeats_place_stats_daily enable row level security;
alter table if exists public.whoeats_post_companions enable row level security;
alter table if exists public.whoeats_profile_pins enable row level security;
alter table if exists public.whoeats_post_favorites enable row level security;
alter table if exists public.whoeats_device_push_tokens enable row level security;
alter table if exists public.whoeats_notifications enable row level security;
alter table if exists public.whoeats_reports enable row level security;

-- =========================
-- follows / blocks policies
-- =========================

drop policy if exists follows_select on public.whoeats_follows;
create policy follows_select
on public.whoeats_follows
for select
to authenticated
using (follower_id = auth.uid() or following_id = auth.uid());

drop policy if exists follows_insert_self on public.whoeats_follows;
create policy follows_insert_self
on public.whoeats_follows
for insert
to authenticated
with check (follower_id = auth.uid());

drop policy if exists follows_delete_self on public.whoeats_follows;
create policy follows_delete_self
on public.whoeats_follows
for delete
to authenticated
using (follower_id = auth.uid());

drop policy if exists blocks_select on public.whoeats_blocks;
create policy blocks_select
on public.whoeats_blocks
for select
to authenticated
using (blocker_id = auth.uid() or blocked_id = auth.uid());

drop policy if exists blocks_insert_self on public.whoeats_blocks;
create policy blocks_insert_self
on public.whoeats_blocks
for insert
to authenticated
with check (blocker_id = auth.uid());

drop policy if exists blocks_delete_self on public.whoeats_blocks;
create policy blocks_delete_self
on public.whoeats_blocks
for delete
to authenticated
using (blocker_id = auth.uid());

-- =========================
-- posts write policies
-- (select policies come from visibility migrations)
-- =========================

drop policy if exists posts_insert_self on public.whoeats_posts;
create policy posts_insert_self
on public.whoeats_posts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists posts_update_self on public.whoeats_posts;
create policy posts_update_self
on public.whoeats_posts
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- =========================
-- post_images write policies
-- =========================

drop policy if exists post_images_insert_by_owner on public.whoeats_post_images;
create policy post_images_insert_by_owner
on public.whoeats_post_images
for insert
to authenticated
with check (
  exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists post_images_update_by_owner on public.whoeats_post_images;
create policy post_images_update_by_owner
on public.whoeats_post_images
for update
to authenticated
using (
  exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.whoeats_posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
);

-- =========================
-- comments / reactions write policies
-- =========================

drop policy if exists post_comments_update_self on public.whoeats_post_comments;
create policy post_comments_update_self
on public.whoeats_post_comments
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists post_reactions_delete_self on public.whoeats_post_reactions;
create policy post_reactions_delete_self
on public.whoeats_post_reactions
for delete
to authenticated
using (user_id = auth.uid());

-- =========================
-- places / stats (authenticated read)
-- =========================

drop policy if exists places_select_all on public.whoeats_places;
create policy places_select_all
on public.whoeats_places
for select
to authenticated
using (true);

drop policy if exists place_stats_daily_select_all on public.whoeats_place_stats_daily;
create policy place_stats_daily_select_all
on public.whoeats_place_stats_daily
for select
to authenticated
using (true);

drop policy if exists places_insert_authenticated on public.whoeats_places;
create policy places_insert_authenticated
on public.whoeats_places
for insert
to authenticated
with check (true);

commit;
