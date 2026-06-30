begin;

-- whoeats_users.email は users_email_key（旧 public.users）で一意。
-- auth.users と id がずれた孤立行・削除済み行が同じ email を保持していると、
-- 初回プロフィール保存の INSERT が 23505 になる。

create or replace function public.whoeats_release_stale_profile_email(
  p_email text,
  p_uid uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := nullif(trim(p_email), '');
begin
  if v_email is null or p_uid is null then
    return;
  end if;

  update public.whoeats_users u
  set
    email = u.id::text || '@released.who-eats.internal',
    updated_at = now()
  where u.email = v_email
    and u.id <> p_uid
    and (
      u.deleted_at is not null
      or not exists (select 1 from auth.users a where a.id = u.id)
    );
end;
$$;

create or replace function public.ensure_whoeats_user_row()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  user_email text;
  safe_email text;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select email into user_email from auth.users where id = uid;
  safe_email := coalesce(nullif(trim(user_email), ''), uid::text || '@users.who-eats.placeholder');

  perform public.whoeats_release_stale_profile_email(safe_email, uid);

  insert into public.whoeats_users (id, email)
  values (uid, safe_email)
  on conflict (id) do update
    set email = excluded.email
    where public.whoeats_users.email is distinct from excluded.email;
end;
$$;

create or replace function public.save_whoeats_profile(
  p_name text,
  p_user_code text,
  p_bio text default null,
  p_icon_path text default null
)
returns public.whoeats_users
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  user_email text;
  safe_email text;
  v_name text;
  v_code text;
  v_bio text;
  v_icon text;
  result public.whoeats_users;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  v_name := nullif(trim(p_name), '');
  v_code := nullif(trim(p_user_code), '');
  v_bio := nullif(trim(p_bio), '');
  v_icon := nullif(trim(p_icon_path), '');

  if v_name is null or v_code is null then
    raise exception 'name and user_code are required';
  end if;

  if char_length(v_name) > 10 then
    v_name := left(v_name, 10);
  end if;

  if v_code !~ '^@[A-Za-z0-9_]+$' or char_length(v_code) > 15 then
    raise exception 'invalid user_code';
  end if;

  select email into user_email from auth.users where id = uid;
  safe_email := coalesce(nullif(trim(user_email), ''), uid::text || '@users.who-eats.placeholder');

  perform public.whoeats_release_stale_profile_email(safe_email, uid);

  insert into public.whoeats_users (id, email, name, user_code, bio, icon_path)
  values (uid, safe_email, v_name, v_code, v_bio, v_icon)
  on conflict (id) do update set
    email = excluded.email,
    name = excluded.name,
    user_code = excluded.user_code,
    bio = excluded.bio,
    icon_path = coalesce(excluded.icon_path, public.whoeats_users.icon_path),
    updated_at = now()
  returning * into result;

  return result;
end;
$$;

revoke all on function public.whoeats_release_stale_profile_email(text, uuid) from public;
grant execute on function public.whoeats_release_stale_profile_email(text, uuid) to authenticated;

revoke all on function public.ensure_whoeats_user_row() from public;
grant execute on function public.ensure_whoeats_user_row() to authenticated;

revoke all on function public.save_whoeats_profile(text, text, text, text) from public;
grant execute on function public.save_whoeats_profile(text, text, text, text) to authenticated;

commit;
