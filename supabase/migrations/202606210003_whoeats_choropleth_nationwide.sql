begin;

-- 複数都道府県表示時は1回の RPC で全国の投稿カバレッジを取得する。

create or replace function public.whoeats_map_choropleth_nationwide()
returns table (
  city_code text,
  city_name text,
  has_mine boolean,
  has_friend boolean,
  has_other boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with viewer as (
    select auth.uid() as uid
  ),
  visible_posts as (
    select
      p.user_id,
      trim(pl.city_code) as city_code,
      pl.city_name
    from public.whoeats_posts p
    join public.whoeats_places pl on pl.id = p.place_id
    cross join viewer v
    where p.deleted_at is null
      and p.post_type = 'restaurant'
      and pl.city_code is not null
      and length(trim(pl.city_code)) >= 2
      and (
        p.user_id = v.uid
        or p.visibility = 'public'
        or (
          p.visibility = 'friends'
          and v.uid is not null
          and public.is_friends(v.uid, p.user_id)
        )
      )
  ),
  city_agg as (
    select
      vp.city_code,
      min(vp.city_name) as city_name,
      bool_or(vp.user_id = (select uid from viewer)) as has_mine,
      bool_or(
        vp.user_id <> (select uid from viewer)
        and (select uid from viewer) is not null
        and public.is_friends((select uid from viewer), vp.user_id)
      ) as has_friend,
      bool_or(
        vp.user_id <> (select uid from viewer)
        and (
          (select uid from viewer) is null
          or not public.is_friends((select uid from viewer), vp.user_id)
        )
      ) as has_other
    from visible_posts vp
    group by vp.city_code
  )
  select
    ca.city_code,
    ca.city_name,
    ca.has_mine,
    ca.has_friend,
    ca.has_other
  from city_agg ca
  order by ca.city_code;
$$;

revoke all on function public.whoeats_map_choropleth_nationwide() from public;
grant execute on function public.whoeats_map_choropleth_nationwide() to authenticated;

commit;
