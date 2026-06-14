begin;

-- whoeats_users: 初回ログイン時の行作成・プロフィール保存を確実にする。
-- 共有 DB で bootstrap のみ入った環境では RLS / GRANT が不足していることがある。

alter table public.whoeats_users
  alter column name drop not null;

alter table public.whoeats_users
  alter column user_code drop not null;

alter table public.whoeats_users enable row level security;

grant select, insert, update on public.whoeats_users to authenticated;
grant select on public.whoeats_users to anon;

drop policy if exists users_select_public on public.whoeats_users;
drop policy if exists users_update_self on public.whoeats_users;
drop policy if exists users_insert_self on public.whoeats_users;
drop policy if exists whoeats_users_select_authenticated on public.whoeats_users;
drop policy if exists whoeats_users_insert_self on public.whoeats_users;
drop policy if exists whoeats_users_update_self on public.whoeats_users;

create policy whoeats_users_select_authenticated
on public.whoeats_users
for select
to authenticated
using (deleted_at is null);

create policy whoeats_users_insert_self
on public.whoeats_users
for insert
to authenticated
with check (auth.uid() = id);

create policy whoeats_users_update_self
on public.whoeats_users
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- ログイン直後: auth.users にいるが whoeats_users 行が無い場合に空行を用意する。
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

  insert into public.whoeats_users (id, email)
  values (uid, safe_email)
  on conflict (id) do update
    set email = excluded.email
    where public.whoeats_users.email is distinct from excluded.email;
end;
$$;

-- 初回プロフィール入力: RLS を迂回して upsert する。
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

revoke all on function public.ensure_whoeats_user_row() from public;
grant execute on function public.ensure_whoeats_user_row() to authenticated;

revoke all on function public.save_whoeats_profile(text, text, text, text) from public;
grant execute on function public.save_whoeats_profile(text, text, text, text) to authenticated;

commit;
