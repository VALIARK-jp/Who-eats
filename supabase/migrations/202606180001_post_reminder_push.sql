begin;

-- 最終投稿から24時間経過したユーザーへ push リマインドを送るための列・RPC。

alter table public.whoeats_users
  add column if not exists last_posted_at timestamptz null;

alter table public.whoeats_users
  add column if not exists post_reminder_sent_at timestamptz null;

comment on column public.whoeats_users.last_posted_at is
  '直近の食事投稿日時（whoeats_posts.created_at と同期）';
comment on column public.whoeats_users.post_reminder_sent_at is
  '24時間リマインド push を最後に送った日時';

-- 既存投稿から backfill
update public.whoeats_users u
set last_posted_at = sub.max_created
from (
  select p.user_id, max(p.created_at) as max_created
  from public.whoeats_posts p
  where p.deleted_at is null
  group by p.user_id
) sub
where u.id = sub.user_id
  and u.last_posted_at is null;

create or replace function public.bump_user_streak_on_post()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid := auth.uid();
  today date := (timezone('Asia/Tokyo', now()))::date;
  last date;
  s int;
begin
  if u is null then
    return;
  end if;

  select last_posted_on, streak_days
  into last, s
  from public.whoeats_users
  where id = u and deleted_at is null;

  if not found then
    return;
  end if;

  if last is null then
    s := 1;
  elsif last = today then
    s := greatest(s, 1);
  elsif last = today - 1 then
    s := s + 1;
  else
    s := 1;
  end if;

  update public.whoeats_users
  set streak_days = s,
      last_posted_on = today,
      last_posted_at = now(),
      post_reminder_sent_at = null,
      updated_at = now()
  where id = u;
end;
$$;

-- 友達・公開フィードで直近48時間以内に投稿したユーザーの表示名（最大 p_limit 件）
create or replace function public.get_recent_feed_poster_names(
  p_viewer uuid,
  p_limit int default 2
)
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  with recent as (
    select distinct on (p.user_id)
      nullif(trim(u.name), '') as display_name,
      nullif(trim(u.user_code), '') as user_code,
      p.created_at
    from public.whoeats_posts p
    join public.whoeats_users u on u.id = p.user_id
    where p.deleted_at is null
      and u.deleted_at is null
      and p.user_id <> p_viewer
      and p.created_at >= now() - interval '48 hours'
      and not public.is_blocked(p_viewer, p.user_id)
      and (
        (
          public.is_friends(p_viewer, p.user_id)
          and p.visibility in ('friends', 'near', 'public')
        )
        or p.visibility = 'public'
        or (
          p.visibility = 'near'
          and exists (
            select 1
            from public.whoeats_follows f1
            join public.whoeats_follows f2 on f2.follower_id = f1.following_id
            where f1.follower_id = p_viewer
              and f2.following_id = p.user_id
              and f2.following_id <> p_viewer
              and not public.is_friends(p_viewer, f2.following_id)
              and not public.is_blocked(p_viewer, f2.following_id)
          )
        )
      )
    order by p.user_id, p.created_at desc
  )
  select coalesce(
    array_agg(
      coalesce(display_name, user_code, 'ユーザー')
      order by created_at desc
    ),
    '{}'::text[]
  )
  from (
    select display_name, user_code, created_at
    from recent
    order by created_at desc
    limit greatest(p_limit, 0)
  ) picked;
$$;

revoke all on function public.get_recent_feed_poster_names(uuid, int) from public;
grant execute on function public.get_recent_feed_poster_names(uuid, int) to service_role;

-- 24時間リマインド対象（push トークン登録済み・プロフィール完成済み）
create or replace function public.list_post_reminder_candidates(p_limit int default 100)
returns table (
  user_id uuid,
  recent_poster_names text[]
)
language sql
stable
security definer
set search_path = public
as $$
  with eligible as (
    select
      u.id as user_id,
      coalesce(
        u.last_posted_at,
        (
          select max(p.created_at)
          from public.whoeats_posts p
          where p.user_id = u.id
            and p.deleted_at is null
        ),
        u.created_at
      ) as last_activity_at,
      u.post_reminder_sent_at
    from public.whoeats_users u
    where u.deleted_at is null
      and u.name is not null
      and trim(u.name) <> ''
      and u.name <> 'User'
      and u.user_code is not null
      and trim(u.user_code) <> ''
      and exists (
        select 1
        from public.whoeats_device_push_tokens t
        where t.user_id = u.id
      )
  )
  select
    e.user_id,
    public.get_recent_feed_poster_names(e.user_id, 2) as recent_poster_names
  from eligible e
  where e.last_activity_at <= now() - interval '24 hours'
    and (
      e.post_reminder_sent_at is null
      or e.post_reminder_sent_at < e.last_activity_at
    )
  order by e.last_activity_at asc
  limit greatest(p_limit, 0);
$$;

revoke all on function public.list_post_reminder_candidates(int) from public;
grant execute on function public.list_post_reminder_candidates(int) to service_role;

create or replace function public.mark_post_reminder_sent(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;

  update public.whoeats_users
  set post_reminder_sent_at = now(),
      updated_at = now()
  where id = p_user_id
    and deleted_at is null;
end;
$$;

revoke all on function public.mark_post_reminder_sent(uuid) from public;
grant execute on function public.mark_post_reminder_sent(uuid) to service_role;

commit;
