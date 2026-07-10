begin;

-- 0003 renamed Who eats domain tables to `whoeats_*`.
-- SQL function bodies are not rewritten by that rename, so RLS checks that call
-- these helpers can still try to read `public.blocks` / `public.follows`.

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.whoeats_blocks
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

commit;
