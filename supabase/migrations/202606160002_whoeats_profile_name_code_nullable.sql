begin;

-- 初回プロフィール入力まで name / user_code を未設定（null）にできるようにする。
alter table public.whoeats_users
  alter column name drop not null;

alter table public.whoeats_users
  alter column user_code drop not null;

commit;
