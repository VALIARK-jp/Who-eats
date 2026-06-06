begin;

create or replace function public.soft_delete_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.whoeats_posts
  set deleted_at = now()
  where id = p_post_id
    and user_id = auth.uid()
    and deleted_at is null;

  if not found then
    raise exception 'post not found or not owned by current user';
  end if;
end;
$$;

revoke all on function public.soft_delete_post(uuid) from public;
grant execute on function public.soft_delete_post(uuid) to authenticated;

commit;
