-- Prefix match search for @user_code (friend discovery).

create or replace function public.search_users_by_code(p_query text, p_limit int default 20)
returns table (
  user_id uuid,
  name text,
  user_code text,
  icon_path text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id as user_id,
    u.name,
    u.user_code,
    u.icon_path
  from public.whoeats_users u
  where auth.uid() is not null
    and u.deleted_at is null
    and u.id <> auth.uid()
    and not public.is_blocked(auth.uid(), u.id)
    and length(trim(coalesce(p_query, ''))) >= 2
    and u.user_code ilike trim(p_query) || '%'
  order by u.user_code
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$$;

revoke all on function public.search_users_by_code(text, int) from public;
grant execute on function public.search_users_by_code(text, int) to authenticated;
