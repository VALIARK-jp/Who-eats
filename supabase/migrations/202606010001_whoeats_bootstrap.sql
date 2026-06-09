-- Bootstrap Who eats schema for shared valiark-prod history.
-- The remote migration history already includes older entries, but the actual
-- database is missing the `whoeats_*` tables needed by later migrations.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.whoeats_users (
  id uuid primary key,
  user_code text not null unique,
  name text not null,
  email text not null unique,
  icon_path text null,
  bio text null,
  default_visibility text not null default 'friends',
  streak_days int not null default 0,
  last_posted_on date null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint whoeats_users_default_visibility_check
    check (default_visibility in ('public','friends','private')),
  constraint whoeats_users_bio_length_check
    check (bio is null or char_length(bio) <= 160),
  constraint whoeats_users_user_code_format_check
    check (user_code ~ '^@[A-Za-z0-9_]+$')
);

create trigger trg_whoeats_users_updated_at
before update on public.whoeats_users
for each row execute function public.set_updated_at();

create table if not exists public.whoeats_follows (
  follower_id uuid not null,
  following_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint whoeats_follows_no_self_check check (follower_id <> following_id),
  constraint whoeats_follows_follower_fk foreign key (follower_id) references public.whoeats_users(id) on delete cascade,
  constraint whoeats_follows_following_fk foreign key (following_id) references public.whoeats_users(id) on delete cascade
);

create table if not exists public.whoeats_blocks (
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint whoeats_blocks_no_self_check check (blocker_id <> blocked_id),
  constraint whoeats_blocks_blocker_fk foreign key (blocker_id) references public.whoeats_users(id) on delete cascade,
  constraint whoeats_blocks_blocked_fk foreign key (blocked_id) references public.whoeats_users(id) on delete cascade
);

create table if not exists public.whoeats_places (
  id uuid primary key default gen_random_uuid(),
  google_place_id text not null unique,
  name text not null,
  address text null,
  latitude double precision not null,
  longitude double precision not null,
  category text null,
  source text not null default 'google',
  place_status text not null default 'active',
  business_status text null,
  last_verified_at timestamptz null,
  verify_fail_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint whoeats_places_source_check check (source in ('google','manual')),
  constraint whoeats_places_status_check check (place_status in ('active','closed','not_found','inactive'))
);

create trigger trg_whoeats_places_updated_at
before update on public.whoeats_places
for each row execute function public.set_updated_at();

create table if not exists public.whoeats_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  place_id uuid null,
  post_type text not null,
  visibility text not null,
  caption text null,
  rating int null,
  visited_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint whoeats_posts_post_type_check check (post_type in ('restaurant','home')),
  constraint whoeats_posts_visibility_check check (visibility in ('public','friends','private')),
  constraint whoeats_posts_rating_check check (rating is null or rating between 1 and 5),
  constraint whoeats_posts_place_required_for_restaurant_check
    check ((post_type <> 'restaurant') or (place_id is not null)),
  constraint whoeats_posts_user_fk foreign key (user_id) references public.whoeats_users(id) on delete cascade,
  constraint whoeats_posts_place_fk foreign key (place_id) references public.whoeats_places(id) on delete set null
);

create trigger trg_whoeats_posts_updated_at
before update on public.whoeats_posts
for each row execute function public.set_updated_at();

create table if not exists public.whoeats_post_images (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  storage_path text not null,
  display_order int not null default 0,
  width int null,
  height int null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint whoeats_post_images_post_fk foreign key (post_id) references public.whoeats_posts(id) on delete cascade,
  constraint whoeats_post_images_unique_order unique (post_id, display_order)
);

create table if not exists public.whoeats_post_reactions (
  post_id uuid not null,
  user_id uuid not null,
  reaction_type text not null default 'like',
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, reaction_type),
  constraint whoeats_post_reactions_post_fk foreign key (post_id) references public.whoeats_posts(id) on delete cascade,
  constraint whoeats_post_reactions_user_fk foreign key (user_id) references public.whoeats_users(id) on delete cascade
);

create table if not exists public.whoeats_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  user_id uuid not null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint whoeats_post_comments_post_fk foreign key (post_id) references public.whoeats_posts(id) on delete cascade,
  constraint whoeats_post_comments_user_fk foreign key (user_id) references public.whoeats_users(id) on delete cascade
);

create trigger trg_whoeats_post_comments_updated_at
before update on public.whoeats_post_comments
for each row execute function public.set_updated_at();

create table if not exists public.whoeats_place_stats_daily (
  place_id uuid not null,
  stat_date date not null,
  post_count int not null default 0,
  reaction_count int not null default 0,
  unique_user_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (place_id, stat_date),
  constraint whoeats_place_stats_daily_place_fk foreign key (place_id) references public.whoeats_places(id) on delete cascade
);

create trigger trg_whoeats_place_stats_daily_updated_at
before update on public.whoeats_place_stats_daily
for each row execute function public.set_updated_at();

create index if not exists idx_whoeats_posts_user_created_at on public.whoeats_posts (user_id, created_at desc);
create index if not exists idx_whoeats_posts_place_created_at on public.whoeats_posts (place_id, created_at desc);
create index if not exists idx_whoeats_posts_visibility_created_at on public.whoeats_posts (visibility, created_at desc);
create index if not exists idx_whoeats_follows_following_id on public.whoeats_follows (following_id);
create index if not exists idx_whoeats_follows_follower_id on public.whoeats_follows (follower_id);
create index if not exists idx_whoeats_post_images_post_order on public.whoeats_post_images (post_id, display_order);
create index if not exists idx_whoeats_place_stats_daily_date_post_count on public.whoeats_place_stats_daily (stat_date, post_count desc);

insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', false)
on conflict (id) do update set public = excluded.public;
