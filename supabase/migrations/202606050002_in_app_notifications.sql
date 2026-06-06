begin;

create table if not exists public.whoeats_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references public.whoeats_users(id) on delete cascade,
  actor_user_id uuid references public.whoeats_users(id) on delete set null,
  event_type text not null,
  title text not null,
  body text not null,
  post_id uuid null,
  comment_id uuid null,
  friend_id uuid null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_whoeats_notifications_recipient_created_at
  on public.whoeats_notifications (recipient_user_id, created_at desc);

create index if not exists idx_whoeats_notifications_recipient_unread_created_at
  on public.whoeats_notifications (recipient_user_id, is_read, created_at desc);

create trigger trg_whoeats_notifications_updated_at
before update on public.whoeats_notifications
for each row execute function public.set_updated_at();

alter table public.whoeats_notifications enable row level security;

drop policy if exists "notifications are readable by owner" on public.whoeats_notifications;
create policy "notifications are readable by owner"
  on public.whoeats_notifications
  for select
  using (auth.uid() = recipient_user_id);

drop policy if exists "notifications are updatable by owner" on public.whoeats_notifications;
create policy "notifications are updatable by owner"
  on public.whoeats_notifications
  for update
  using (auth.uid() = recipient_user_id)
  with check (auth.uid() = recipient_user_id);

create or replace function public.insert_whoeats_notification(
  p_recipient_user_id uuid,
  p_actor_user_id uuid,
  p_event_type text,
  p_title text,
  p_body text,
  p_post_id uuid default null,
  p_comment_id uuid default null,
  p_friend_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient_user_id is null or p_event_type is null or p_title is null or p_body is null then
    return;
  end if;

  insert into public.whoeats_notifications (
    recipient_user_id,
    actor_user_id,
    event_type,
    title,
    body,
    post_id,
    comment_id,
    friend_id
  ) values (
    p_recipient_user_id,
    p_actor_user_id,
    p_event_type,
    p_title,
    p_body,
    p_post_id,
    p_comment_id,
    p_friend_id
  );
end;
$$;

revoke all on function public.insert_whoeats_notification(uuid, uuid, text, text, text, uuid, uuid, uuid) from public;
grant execute on function public.insert_whoeats_notification(uuid, uuid, text, text, text, uuid, uuid, uuid) to authenticated;

create or replace function public.handle_whoeats_post_reaction_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  if new.reaction_type is distinct from 'like' then
    return new;
  end if;

  select p.user_id
    into owner_id
    from public.whoeats_posts p
   where p.id = new.post_id
     and p.deleted_at is null;

  if owner_id is null or owner_id = new.user_id then
    return new;
  end if;

  select coalesce(u.name, u.user_code, 'ユーザー')
    into actor_name
    from public.whoeats_users u
   where u.id = new.user_id;

  perform public.insert_whoeats_notification(
    owner_id,
    new.user_id,
    'like',
    'いいねが届きました',
    coalesce(actor_name, 'ユーザー') || ' さんがあなたの投稿にいいねしました',
    new.post_id,
    null,
    null
  );

  return new;
end;
$$;

drop trigger if exists trg_whoeats_post_reaction_notification on public.whoeats_post_reactions;
create trigger trg_whoeats_post_reaction_notification
after insert on public.whoeats_post_reactions
for each row execute function public.handle_whoeats_post_reaction_notification();

create or replace function public.handle_whoeats_post_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  actor_name text;
begin
  select p.user_id
    into owner_id
    from public.whoeats_posts p
   where p.id = new.post_id
     and p.deleted_at is null;

  if owner_id is null or owner_id = new.user_id then
    return new;
  end if;

  select coalesce(u.name, u.user_code, 'ユーザー')
    into actor_name
    from public.whoeats_users u
   where u.id = new.user_id;

  perform public.insert_whoeats_notification(
    owner_id,
    new.user_id,
    'comment',
    'コメントが届きました',
    coalesce(actor_name, 'ユーザー') || ' さんがあなたの投稿にコメントしました',
    new.post_id,
    new.id,
    null
  );

  return new;
end;
$$;

drop trigger if exists trg_whoeats_post_comment_notification on public.whoeats_post_comments;
create trigger trg_whoeats_post_comment_notification
after insert on public.whoeats_post_comments
for each row execute function public.handle_whoeats_post_comment_notification();

create or replace function public.handle_whoeats_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  event_title text;
  event_body text;
  event_type text;
begin
  if new.follower_id = new.following_id then
    return new;
  end if;

  select coalesce(u.name, u.user_code, 'ユーザー')
    into actor_name
    from public.whoeats_users u
   where u.id = new.follower_id;

  if exists (
    select 1
      from public.whoeats_follows f
     where f.follower_id = new.following_id
       and f.following_id = new.follower_id
  ) then
    event_type := 'friend_accepted';
    event_title := '友達になりました';
    event_body := coalesce(actor_name, 'ユーザー') || ' さんと友達になりました';
  else
    event_type := 'friend_request';
    event_title := '友達申請が届きました';
    event_body := coalesce(actor_name, 'ユーザー') || ' さんから友達申請が届きました';
  end if;

  perform public.insert_whoeats_notification(
    new.following_id,
    new.follower_id,
    event_type,
    event_title,
    event_body,
    null,
    null,
    new.follower_id
  );

  return new;
end;
$$;

drop trigger if exists trg_whoeats_follow_notification on public.whoeats_follows;
create trigger trg_whoeats_follow_notification
after insert on public.whoeats_follows
for each row execute function public.handle_whoeats_follow_notification();

commit;
