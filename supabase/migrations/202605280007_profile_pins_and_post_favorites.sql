-- Profile pins (own posts on profile) and post favorites (bookmark others' posts).

create table if not exists public.whoeats_profile_pins (
  user_id uuid not null references public.whoeats_users (id) on delete cascade,
  post_id uuid not null references public.whoeats_posts (id) on delete cascade,
  primary key (user_id, post_id)
);

create index if not exists whoeats_profile_pins_user_id_idx
  on public.whoeats_profile_pins (user_id);

create table if not exists public.whoeats_post_favorites (
  user_id uuid not null references public.whoeats_users (id) on delete cascade,
  post_id uuid not null references public.whoeats_posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index if not exists whoeats_post_favorites_user_created_idx
  on public.whoeats_post_favorites (user_id, created_at desc);

alter table public.whoeats_profile_pins enable row level security;
alter table public.whoeats_post_favorites enable row level security;

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

-- Pin own post on profile (max 3). Unpin when p_pin = false.
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

-- Toggle favorite on someone else's post. Returns true if now favorited.
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

grant execute on function public.set_profile_post_pinned(uuid, boolean) to authenticated;
grant execute on function public.toggle_post_favorite(uuid) to authenticated;
