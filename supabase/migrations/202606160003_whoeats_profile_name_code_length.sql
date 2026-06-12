begin;

-- 既に上限を超えている既存行だけ切り詰める（新規入力のガードはアプリ側）。
update public.whoeats_users
set name = left(trim(name), 10)
where name is not null
  and char_length(trim(name)) > 10;

update public.whoeats_users
set user_code = left(user_code, 15)
where user_code is not null
  and char_length(user_code) > 15;

commit;
