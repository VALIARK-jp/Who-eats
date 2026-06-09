begin;

-- 202606050001 はリモートで別マイグレーションに使われていたため、テーブルが未作成だった。
create table if not exists public.whoeats_device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.whoeats_users(id) on delete cascade,
  fcm_token text not null,
  platform text not null default '',
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (fcm_token)
);

alter table public.whoeats_device_push_tokens enable row level security;

drop policy if exists "device push tokens are readable by owner" on public.whoeats_device_push_tokens;
create policy "device push tokens are readable by owner"
  on public.whoeats_device_push_tokens
  for select
  using (auth.uid() = user_id);

drop policy if exists "device push tokens are insertable by owner" on public.whoeats_device_push_tokens;
create policy "device push tokens are insertable by owner"
  on public.whoeats_device_push_tokens
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "device push tokens are updatable by owner" on public.whoeats_device_push_tokens;
create policy "device push tokens are updatable by owner"
  on public.whoeats_device_push_tokens
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "device push tokens are deletable by owner" on public.whoeats_device_push_tokens;
create policy "device push tokens are deletable by owner"
  on public.whoeats_device_push_tokens
  for delete
  using (auth.uid() = user_id);

create or replace function public.register_device_push_token(
  p_fcm_token text,
  p_platform text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if coalesce(trim(p_fcm_token), '') = '' then
    raise exception 'fcm_token is required';
  end if;

  delete from public.whoeats_device_push_tokens
  where fcm_token = p_fcm_token;

  insert into public.whoeats_device_push_tokens (
    user_id,
    fcm_token,
    platform,
    last_seen_at,
    updated_at
  ) values (
    v_uid,
    p_fcm_token,
    coalesce(p_platform, ''),
    now(),
    now()
  );
end;
$$;

revoke all on function public.register_device_push_token(text, text) from public;
grant execute on function public.register_device_push_token(text, text) to authenticated;

notify pgrst, 'reload schema';

commit;
