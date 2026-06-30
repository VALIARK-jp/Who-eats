-- 市区町村コード（geolonia/japanese-admins 準拠）を店舗に紐づけ、マップコロプレス用に集計する。

alter table public.whoeats_places
  add column if not exists prefecture_code char(2) null,
  add column if not exists city_code text null,
  add column if not exists city_name text null;

create index if not exists idx_whoeats_places_city_code
  on public.whoeats_places (city_code)
  where city_code is not null;

create index if not exists idx_whoeats_places_prefecture_code
  on public.whoeats_places (prefecture_code)
  where prefecture_code is not null;

comment on column public.whoeats_places.city_code is
  '市区町村コード（5桁）。lat/lng から geolonia 境界で解決。';
comment on column public.whoeats_places.prefecture_code is
  '都道府県コード（2桁）。city_code 先頭2桁と一致。';
comment on column public.whoeats_places.city_name is
  '市区町村名（表示用）。';

-- 都道府県内の市ごと投稿カバレッジ（mine > friend > other > none）
create or replace function public.whoeats_map_choropleth_prefecture(
  p_prefecture_code text
)
returns jsonb
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
      pl.city_code,
      pl.city_name
    from public.whoeats_posts p
    join public.whoeats_places pl on pl.id = p.place_id
    cross join viewer v
    where p.deleted_at is null
      and p.post_type = 'restaurant'
      and pl.city_code is not null
      and pl.prefecture_code = p_prefecture_code
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
  select jsonb_build_object(
    'prefecture_code', p_prefecture_code,
    'cities', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'city_code', ca.city_code,
            'city_name', ca.city_name,
            'has_mine', ca.has_mine,
            'has_friend', ca.has_friend,
            'has_other', ca.has_other
          )
          order by ca.city_code
        )
        from city_agg ca
      ),
      '[]'::jsonb
    )
  );
$$;

revoke all on function public.whoeats_map_choropleth_prefecture(text) from public;
grant execute on function public.whoeats_map_choropleth_prefecture(text) to authenticated;
