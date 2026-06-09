begin;

-- マップ用: 半径内の「誰かが投稿した店」＋訪問者（投稿本文は返さない）
create or replace function public.get_restaurant_post_activity_in_radius(
  p_lat double precision,
  p_lng double precision,
  p_radius_meters int default 6000
)
returns table (
  google_place_id text,
  place_name text,
  latitude double precision,
  longitude double precision,
  user_id uuid,
  user_name text
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  )
  select distinct
    pl.google_place_id,
    pl.name as place_name,
    pl.latitude,
    pl.longitude,
    p.user_id,
    u.name as user_name
  from public.whoeats_posts p
  join public.whoeats_places pl on pl.id = p.place_id
  join public.whoeats_users u on u.id = p.user_id
  where p.post_type = 'restaurant'
    and p.deleted_at is null
    and u.deleted_at is null
    and pl.google_place_id is not null
    and (select uid from me) is not null
    and not public.is_blocked((select uid from me), p.user_id)
    and (
      6371000 * acos(
        least(
          1.0,
          greatest(
            -1.0,
            cos(radians(p_lat)) * cos(radians(pl.latitude))
              * cos(radians(pl.longitude) - radians(p_lng))
              + sin(radians(p_lat)) * sin(radians(pl.latitude))
          )
        )
      )
    ) <= p_radius_meters
  order by google_place_id, user_name;
$$;

create or replace function public.get_place_visitors(p_google_place_id text)
returns table (
  user_id uuid,
  user_name text
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  )
  select distinct
    p.user_id,
    u.name as user_name
  from public.whoeats_posts p
  join public.whoeats_places pl on pl.id = p.place_id
  join public.whoeats_users u on u.id = p.user_id
  where pl.google_place_id = p_google_place_id
    and p.post_type = 'restaurant'
    and p.deleted_at is null
    and u.deleted_at is null
    and (select uid from me) is not null
    and not public.is_blocked((select uid from me), p.user_id)
  order by u.name;
$$;

revoke all on function public.get_restaurant_post_activity_in_radius(double precision, double precision, int) from public;
grant execute on function public.get_restaurant_post_activity_in_radius(double precision, double precision, int) to authenticated;

revoke all on function public.get_place_visitors(text) from public;
grant execute on function public.get_place_visitors(text) to authenticated;

commit;
