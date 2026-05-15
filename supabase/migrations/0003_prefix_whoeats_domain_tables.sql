begin;

-- In a single Supabase project (valiark-dev), multiple apps share `public`.
-- Prefix Who eats domain tables to avoid name collisions (e.g. with other apps).
--
-- NOTE: This migration is designed to run AFTER 0001/0002.

alter table if exists public.users rename to whoeats_users;
alter table if exists public.follows rename to whoeats_follows;
alter table if exists public.blocks rename to whoeats_blocks;
alter table if exists public.places rename to whoeats_places;
alter table if exists public.posts rename to whoeats_posts;
alter table if exists public.post_images rename to whoeats_post_images;
alter table if exists public.post_reactions rename to whoeats_post_reactions;
alter table if exists public.post_comments rename to whoeats_post_comments;
alter table if exists public.place_stats_daily rename to whoeats_place_stats_daily;

commit;

