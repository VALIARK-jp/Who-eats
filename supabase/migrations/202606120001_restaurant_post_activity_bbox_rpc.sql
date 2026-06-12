begin;

-- マップ広域表示: 画面 bbox 内の訪問投稿ピン（半径 RPC の補完）
create or replace function public.get_restaurant_post_activity_in_bbox(
  p_min_lat double precision,
  p_max_lat double precision,
  p_min_lng double precision,
  p_max_lng double precision,
  p_limit int default 500
)
returns table (
  google_place_id text,
  place_name text,
  latitude double precision,
  longitude double precision,
  user_id uuid,
  user_name text,
  icon_path text
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
    u.name as user_name,
    u.icon_path
  from public.whoeats_posts p
  join public.whoeats_places pl on pl.id = p.place_id
  join public.whoeats_users u on u.id = p.user_id
  where p.post_type = 'restaurant'
    and p.deleted_at is null
    and u.deleted_at is null
    and pl.google_place_id is not null
    and pl.latitude is not null
    and pl.longitude is not null
    and (select uid from me) is not null
    and not public.is_blocked((select uid from me), p.user_id)
    and pl.latitude >= least(p_min_lat, p_max_lat)
    and pl.latitude <= greatest(p_min_lat, p_max_lat)
    and pl.longitude >= least(p_min_lng, p_max_lng)
    and pl.longitude <= greatest(p_min_lng, p_max_lng)
  order by google_place_id, user_name
  limit greatest(p_limit, 1);
$$;

revoke all on function public.get_restaurant_post_activity_in_bbox(double precision, double precision, double precision, double precision, int) from public;
grant execute on function public.get_restaurant_post_activity_in_bbox(double precision, double precision, double precision, double precision, int) to authenticated;

commit;
