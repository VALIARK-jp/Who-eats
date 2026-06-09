-- Bootstrap helper functions that later shared-history migrations rely on.

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
