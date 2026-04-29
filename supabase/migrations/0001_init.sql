-- Who eats MVP schema (initial)
-- Source of truth: doc/db-table-design-final-mvp.md
-- Notes:
-- - This migration is intended for Supabase Postgres.
-- - Apply in SQL Editor (or via CLI when adopted).

-- Extensions
create extension if not exists pgcrypto;

-- Helper: updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================
-- Tables
-- =========================

-- 4.1 users
create table if not exists public.users (
  id uuid primary key, -- must match auth.users.id
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
  constraint users_default_visibility_check
    check (default_visibility in ('public','friends','private')),
  constraint users_bio_length_check
    check (bio is null or char_length(bio) <= 160),
  constraint users_user_code_format_check
    check (user_code ~ '^@[A-Za-z0-9_]+$')
);

create trigger trg_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

-- 4.2 follows
create table if not exists public.follows (
  follower_id uuid not null,
  following_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self_check check (follower_id <> following_id),
  constraint follows_follower_fk foreign key (follower_id) references public.users(id) on delete cascade,
  constraint follows_following_fk foreign key (following_id) references public.users(id) on delete cascade
);

-- 4.3 blocks
create table if not exists public.blocks (
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self_check check (blocker_id <> blocked_id),
  constraint blocks_blocker_fk foreign key (blocker_id) references public.users(id) on delete cascade,
  constraint blocks_blocked_fk foreign key (blocked_id) references public.users(id) on delete cascade
);

-- 4.4 places
create table if not exists public.places (
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
  constraint places_source_check check (source in ('google','manual')),
  constraint places_status_check check (place_status in ('active','closed','not_found','inactive'))
);

create trigger trg_places_updated_at
before update on public.places
for each row execute function public.set_updated_at();

-- 4.5 posts
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  place_id uuid null, -- null for home posts
  post_type text not null,
  visibility text not null,
  caption text null,
  rating int null,
  visited_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint posts_post_type_check check (post_type in ('restaurant','home')),
  constraint posts_visibility_check check (visibility in ('public','friends','private')),
  constraint posts_rating_check check (rating is null or rating between 1 and 5),
  constraint posts_place_required_for_restaurant_check
    check ((post_type <> 'restaurant') or (place_id is not null)),
  constraint posts_user_fk foreign key (user_id) references public.users(id) on delete cascade,
  constraint posts_place_fk foreign key (place_id) references public.places(id) on delete set null
);

create trigger trg_posts_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

-- 4.6 post_images
create table if not exists public.post_images (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  storage_path text not null,
  display_order int not null default 0,
  width int null,
  height int null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint post_images_post_fk foreign key (post_id) references public.posts(id) on delete cascade,
  constraint post_images_unique_order unique (post_id, display_order)
);

-- 4.7 post_reactions
create table if not exists public.post_reactions (
  post_id uuid not null,
  user_id uuid not null,
  reaction_type text not null default 'like',
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, reaction_type),
  constraint post_reactions_post_fk foreign key (post_id) references public.posts(id) on delete cascade,
  constraint post_reactions_user_fk foreign key (user_id) references public.users(id) on delete cascade
);

-- 4.8 post_comments
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  user_id uuid not null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint post_comments_post_fk foreign key (post_id) references public.posts(id) on delete cascade,
  constraint post_comments_user_fk foreign key (user_id) references public.users(id) on delete cascade
);

create trigger trg_post_comments_updated_at
before update on public.post_comments
for each row execute function public.set_updated_at();

-- 4.9 place_stats_daily
create table if not exists public.place_stats_daily (
  place_id uuid not null,
  stat_date date not null,
  post_count int not null default 0,
  reaction_count int not null default 0,
  unique_user_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (place_id, stat_date),
  constraint place_stats_daily_place_fk foreign key (place_id) references public.places(id) on delete cascade
);

create trigger trg_place_stats_daily_updated_at
before update on public.place_stats_daily
for each row execute function public.set_updated_at();

-- =========================
-- Indexes (6. 主要インデックス)
-- =========================
create index if not exists idx_posts_user_created_at on public.posts (user_id, created_at desc);
create index if not exists idx_posts_place_created_at on public.posts (place_id, created_at desc);
create index if not exists idx_posts_visibility_created_at on public.posts (visibility, created_at desc);
create index if not exists idx_follows_following_id on public.follows (following_id);
create index if not exists idx_follows_follower_id on public.follows (follower_id);
create index if not exists idx_post_images_post_order on public.post_images (post_id, display_order);
create index if not exists idx_place_stats_daily_date_post_count on public.place_stats_daily (stat_date, post_count desc);

-- =========================
-- RLS (7. RLS方針)
-- =========================

-- Enable RLS
alter table public.users enable row level security;
alter table public.follows enable row level security;
alter table public.blocks enable row level security;
alter table public.posts enable row level security;
alter table public.post_images enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_reactions enable row level security;
alter table public.places enable row level security;
alter table public.place_stats_daily enable row level security;

-- users: public profile readable; only self updatable
drop policy if exists users_select_public on public.users;
create policy users_select_public
on public.users
for select
to authenticated
using (deleted_at is null);

drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists users_insert_self on public.users;
create policy users_insert_self
on public.users
for insert
to authenticated
with check (auth.uid() = id);

-- follows / blocks: only actor can manage
drop policy if exists follows_select on public.follows;
create policy follows_select
on public.follows
for select
to authenticated
using (follower_id = auth.uid() or following_id = auth.uid());

drop policy if exists follows_insert_self on public.follows;
create policy follows_insert_self
on public.follows
for insert
to authenticated
with check (follower_id = auth.uid());

drop policy if exists follows_delete_self on public.follows;
create policy follows_delete_self
on public.follows
for delete
to authenticated
using (follower_id = auth.uid());

drop policy if exists blocks_select on public.blocks;
create policy blocks_select
on public.blocks
for select
to authenticated
using (blocker_id = auth.uid() or blocked_id = auth.uid());

drop policy if exists blocks_insert_self on public.blocks;
create policy blocks_insert_self
on public.blocks
for insert
to authenticated
with check (blocker_id = auth.uid());

drop policy if exists blocks_delete_self on public.blocks;
create policy blocks_delete_self
on public.blocks
for delete
to authenticated
using (blocker_id = auth.uid());

-- helper: are we blocked either way?
create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

-- helper: are users friends (mutual follows)?
create or replace function public.is_friends(a uuid, b uuid)
returns boolean
language sql
stable
as $$
  select exists (select 1 from public.follows where follower_id = a and following_id = b)
     and exists (select 1 from public.follows where follower_id = b and following_id = a);
$$;

-- RPC: friend recommendations with mutual friends count
-- Why: follows RLS is intentionally strict; mutual count / 2-hop should be computed server-side.
create or replace function public.get_friend_recommendations(p_limit int default 50)
returns table (
  user_id uuid,
  user_code text,
  name text,
  icon_path text,
  mutual_count int
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select auth.uid() as me
  ),
  candidates as (
    select
      u.id as user_id,
      u.user_code,
      u.name,
      u.icon_path,
      (
        select count(*)
        from public.users m
        where m.deleted_at is null
          and public.is_friends((select me from me), m.id)
          and public.is_friends(u.id, m.id)
      )::int as mutual_count
    from public.users u
    where u.deleted_at is null
      and u.id <> (select me from me)
      and not public.is_blocked((select me from me), u.id)
      and not exists (
        select 1
        from public.follows f
        where f.follower_id = (select me from me)
          and f.following_id = u.id
      )
  )
  select *
  from candidates
  order by mutual_count desc, user_code asc
  limit p_limit;
$$;

revoke all on function public.get_friend_recommendations(int) from public;
grant execute on function public.get_friend_recommendations(int) to authenticated;

-- posts: owner can CRUD; select by visibility and block relationship
drop policy if exists posts_select_visible on public.posts;
create policy posts_select_visible
on public.posts
for select
to authenticated
using (
  deleted_at is null
  and not public.is_blocked(auth.uid(), user_id)
  and (
    user_id = auth.uid()
    or visibility = 'public'
    or (visibility = 'friends' and public.is_friends(auth.uid(), user_id))
  )
);

drop policy if exists posts_insert_self on public.posts;
create policy posts_insert_self
on public.posts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists posts_update_self on public.posts;
create policy posts_update_self
on public.posts
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- NOTE: MVPは論理削除（deleted_at）を基本とするため、物理DELETEは許可しない。

-- post_images: follow post access
drop policy if exists post_images_select_by_post on public.post_images;
create policy post_images_select_by_post
on public.post_images
for select
to authenticated
using (
  deleted_at is null
  and exists (
    select 1 from public.posts p
    where p.id = post_images.post_id
      and p.deleted_at is null
      and not public.is_blocked(auth.uid(), p.user_id)
      and (
        p.user_id = auth.uid()
        or p.visibility = 'public'
        or (p.visibility = 'friends' and public.is_friends(auth.uid(), p.user_id))
      )
  )
);

drop policy if exists post_images_insert_by_owner on public.post_images;
create policy post_images_insert_by_owner
on public.post_images
for insert
to authenticated
with check (
  exists (
    select 1 from public.posts p
    where p.id = post_images.post_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists post_images_update_by_owner on public.post_images;
create policy post_images_update_by_owner
on public.post_images
for update
to authenticated
using (
  exists (
    select 1 from public.posts p
    where p.id = post_images.post_id
      and p.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.posts p
    where p.id = post_images.post_id
      and p.user_id = auth.uid()
  )
);
-- NOTE: MVPは論理削除（deleted_at）を基本とするため、物理DELETEは許可しない。

-- comments: readable if post readable; creator can write/delete
drop policy if exists post_comments_select_by_post on public.post_comments;
create policy post_comments_select_by_post
on public.post_comments
for select
to authenticated
using (
  deleted_at is null
  and exists (
    select 1 from public.posts p
    where p.id = post_comments.post_id
      and p.deleted_at is null
      and not public.is_blocked(auth.uid(), p.user_id)
      and (
        p.user_id = auth.uid()
        or p.visibility = 'public'
        or (p.visibility = 'friends' and public.is_friends(auth.uid(), p.user_id))
      )
  )
);

drop policy if exists post_comments_insert_on_visible_post on public.post_comments;
create policy post_comments_insert_on_visible_post
on public.post_comments
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.posts p
    where p.id = post_comments.post_id
      and p.deleted_at is null
      and not public.is_blocked(auth.uid(), p.user_id)
      and (
        p.user_id = auth.uid()
        or p.visibility = 'public'
        or (p.visibility = 'friends' and public.is_friends(auth.uid(), p.user_id))
      )
  )
);

drop policy if exists post_comments_update_self on public.post_comments;
create policy post_comments_update_self
on public.post_comments
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- NOTE: MVPは論理削除（deleted_at）を基本とするため、物理DELETEは許可しない。

-- reactions: readable if post readable; creator can write/delete
drop policy if exists post_reactions_select_by_post on public.post_reactions;
create policy post_reactions_select_by_post
on public.post_reactions
for select
to authenticated
using (
  exists (
    select 1 from public.posts p
    where p.id = post_reactions.post_id
      and p.deleted_at is null
      and not public.is_blocked(auth.uid(), p.user_id)
      and (
        p.user_id = auth.uid()
        or p.visibility = 'public'
        or (p.visibility = 'friends' and public.is_friends(auth.uid(), p.user_id))
      )
  )
);

drop policy if exists post_reactions_insert_self on public.post_reactions;
create policy post_reactions_insert_self
on public.post_reactions
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.posts p
    where p.id = post_reactions.post_id
      and p.deleted_at is null
      and not public.is_blocked(auth.uid(), p.user_id)
      and (
        p.user_id = auth.uid()
        or p.visibility = 'public'
        or (p.visibility = 'friends' and public.is_friends(auth.uid(), p.user_id))
      )
  )
);

drop policy if exists post_reactions_delete_self on public.post_reactions;
create policy post_reactions_delete_self
on public.post_reactions
for delete
to authenticated
using (user_id = auth.uid());

-- places: readable to support post views; write is PM-only (service role) so no authenticated insert/update policies.
drop policy if exists places_select_all on public.places;
create policy places_select_all
on public.places
for select
to authenticated
using (true);

-- place_stats_daily: readable (aggregates). write is PM-only (service role).
drop policy if exists place_stats_daily_select_all on public.place_stats_daily;
create policy place_stats_daily_select_all
on public.place_stats_daily
for select
to authenticated
using (true);

