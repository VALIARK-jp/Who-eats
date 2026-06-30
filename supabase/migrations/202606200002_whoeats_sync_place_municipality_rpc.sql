-- 認証ユーザーが店舗の市区町村コードを同期できる RPC（未設定のときのみ）。
-- 共有店舗（他ユーザーの投稿先）も、投稿フローで city_code を初回設定できるようにする。

create or replace function public.whoeats_sync_place_municipality(
  p_place_id uuid,
  p_prefecture_code text,
  p_city_code text,
  p_city_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_place_id is null
     or p_prefecture_code is null or length(trim(p_prefecture_code)) <> 2
     or p_city_code is null or length(trim(p_city_code)) < 4
     or p_city_name is null or length(trim(p_city_name)) = 0 then
    raise exception 'invalid municipality payload';
  end if;

  update public.whoeats_places
  set
    prefecture_code = trim(p_prefecture_code),
    city_code = trim(p_city_code),
    city_name = trim(p_city_name)
  where id = p_place_id
    and (city_code is null or city_code = '');
end;
$$;

revoke all on function public.whoeats_sync_place_municipality(uuid, text, text, text) from public;
grant execute on function public.whoeats_sync_place_municipality(uuid, text, text, text) to authenticated;
