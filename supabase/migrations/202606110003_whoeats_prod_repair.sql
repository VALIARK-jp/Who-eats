begin;

-- Prod repair for the shared valiark database.
-- This migration backfills the Who eats objects that the app expects to exist
-- in later history, plus a legacy FK name that the client still embeds with.

create extension if not exists pgcrypto;

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.whoeats_blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

create or replace function public.is_friends(a uuid, b uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.whoeats_follows
    where follower_id = a and following_id = b
  )
  and exists (
    select 1
    from public.whoeats_follows
    where follower_id = b and following_id = a
  );
$$;

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
        from public.whoeats_users m
        where m.deleted_at is null
          and public.is_friends((select me from me), m.id)
          and public.is_friends(u.id, m.id)
      )::int as mutual_count
    from public.whoeats_users u
    where u.deleted_at is null
      and u.id <> (select me from me)
      and not public.is_blocked((select me from me), u.id)
      and not exists (
        select 1
        from public.whoeats_follows f
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

create table if not exists public.whoeats_profile_pins (
  user_id uuid not null references public.whoeats_users (id) on delete cascade,
  post_id uuid not null references public.whoeats_posts (id) on delete cascade,
  primary key (user_id, post_id)
);

create index if not exists whoeats_profile_pins_user_id_idx
  on public.whoeats_profile_pins (user_id);

alter table public.whoeats_profile_pins enable row level security;

drop policy if exists whoeats_profile_pins_select_own on public.whoeats_profile_pins;
create policy whoeats_profile_pins_select_own
on public.whoeats_profile_pins
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists whoeats_profile_pins_insert_own on public.whoeats_profile_pins;
create policy whoeats_profile_pins_insert_own
on public.whoeats_profile_pins
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists whoeats_profile_pins_delete_own on public.whoeats_profile_pins;
create policy whoeats_profile_pins_delete_own
on public.whoeats_profile_pins
for delete
to authenticated
using (user_id = auth.uid());

create table if not exists public.whoeats_post_favorites (
  user_id uuid not null references public.whoeats_users (id) on delete cascade,
  post_id uuid not null references public.whoeats_posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index if not exists whoeats_post_favorites_user_created_idx
  on public.whoeats_post_favorites (user_id, created_at desc);

alter table public.whoeats_post_favorites enable row level security;

drop policy if exists whoeats_post_favorites_select_own on public.whoeats_post_favorites;
create policy whoeats_post_favorites_select_own
on public.whoeats_post_favorites
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists whoeats_post_favorites_insert_own on public.whoeats_post_favorites;
create policy whoeats_post_favorites_insert_own
on public.whoeats_post_favorites
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists whoeats_post_favorites_delete_own on public.whoeats_post_favorites;
create policy whoeats_post_favorites_delete_own
on public.whoeats_post_favorites
for delete
to authenticated
using (user_id = auth.uid());

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'whoeats_posts'
      and c.conname = 'posts_user_fk'
  ) then
    alter table public.whoeats_posts
      add constraint posts_user_fk
      foreign key (user_id) references public.whoeats_users(id) on delete cascade;
  end if;
end;
$$;

create or replace function public.set_profile_post_pinned(p_post_id uuid, p_pin boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_count int;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select user_id into v_owner
  from public.whoeats_posts
  where id = p_post_id and deleted_at is null;

  if v_owner is null then
    raise exception 'Post not found';
  end if;

  if v_owner <> v_uid then
    raise exception 'Can only pin your own posts';
  end if;

  if p_pin then
    select count(*)::int into v_count
    from public.whoeats_profile_pins
    where user_id = v_uid;

    if v_count >= 3 then
      raise exception 'Pin limit reached (max 3)';
    end if;

    insert into public.whoeats_profile_pins (user_id, post_id)
    values (v_uid, p_post_id)
    on conflict (user_id, post_id) do nothing;
  else
    delete from public.whoeats_profile_pins
    where user_id = v_uid and post_id = p_post_id;
  end if;
end;
$$;

revoke all on function public.set_profile_post_pinned(uuid, boolean) from public;
grant execute on function public.set_profile_post_pinned(uuid, boolean) to authenticated;

create or replace function public.toggle_post_favorite(p_post_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_exists boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select user_id into v_owner
  from public.whoeats_posts
  where id = p_post_id and deleted_at is null;

  if v_owner is null then
    raise exception 'Post not found';
  end if;

  if v_owner = v_uid then
    raise exception 'Cannot favorite your own post';
  end if;

  select exists (
    select 1 from public.whoeats_post_favorites
    where user_id = v_uid and post_id = p_post_id
  ) into v_exists;

  if v_exists then
    delete from public.whoeats_post_favorites
    where user_id = v_uid and post_id = p_post_id;
    return false;
  end if;

  insert into public.whoeats_post_favorites (user_id, post_id)
  values (v_uid, p_post_id);

  return true;
end;
$$;

revoke all on function public.toggle_post_favorite(uuid) from public;
grant execute on function public.toggle_post_favorite(uuid) to authenticated;

commit;
