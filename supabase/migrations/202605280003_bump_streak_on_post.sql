begin;

-- Update streak_days / last_posted_on when the user creates a post (JST calendar day).
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
      updated_at = now()
  where id = u;
end;
$$;

revoke all on function public.bump_user_streak_on_post() from public;
grant execute on function public.bump_user_streak_on_post() to authenticated;

commit;
