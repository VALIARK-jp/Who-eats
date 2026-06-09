begin;

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

commit;
