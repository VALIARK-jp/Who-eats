begin;

create or replace function public.new_meal_group_id()
returns uuid
language sql
volatile
as $$
  select gen_random_uuid();
$$;

revoke all on function public.new_meal_group_id() from public;
grant execute on function public.new_meal_group_id() to authenticated, anon;

alter table public.whoeats_posts
  add column if not exists meal_group_id uuid null;

create index if not exists idx_whoeats_posts_meal_group_id
  on public.whoeats_posts (meal_group_id)
  where meal_group_id is not null;

create table if not exists public.whoeats_post_companions (
  post_id uuid not null,
  user_id uuid not null,
  joined_post_id uuid null,
  created_at timestamptz not null default now(),
  constraint whoeats_post_companions_pk primary key (post_id, user_id),
  constraint whoeats_post_companions_post_fk
    foreign key (post_id) references public.whoeats_posts (id) on delete cascade,
  constraint whoeats_post_companions_user_fk
    foreign key (user_id) references public.whoeats_users (id) on delete cascade,
  constraint whoeats_post_companions_joined_post_fk
    foreign key (joined_post_id) references public.whoeats_posts (id) on delete set null
);

create index if not exists idx_whoeats_post_companions_user_id
  on public.whoeats_post_companions (user_id);

alter table public.whoeats_post_companions enable row level security;

drop policy if exists whoeats_post_companions_select on public.whoeats_post_companions;
create policy whoeats_post_companions_select
on public.whoeats_post_companions
for select
to authenticated
using (
  exists (
    select 1 from public.whoeats_posts p
    where p.id = post_id
      and p.deleted_at is null
      and not public.is_blocked(auth.uid(), p.user_id)
      and (
        p.user_id = auth.uid()
        or user_id = auth.uid()
        or p.visibility = 'public'
        or (p.visibility = 'friends' and public.is_friends(auth.uid(), p.user_id))
      )
  )
);

drop policy if exists whoeats_post_companions_insert_owner on public.whoeats_post_companions;
create policy whoeats_post_companions_insert_owner
on public.whoeats_post_companions
for insert
to authenticated
with check (
  exists (
    select 1 from public.whoeats_posts p
    where p.id = post_id
      and p.user_id = auth.uid()
      and p.deleted_at is null
  )
  and public.is_friends(
    (select p.user_id from public.whoeats_posts p where p.id = post_id),
    user_id
  )
);

drop policy if exists whoeats_post_companions_update_tagged on public.whoeats_post_companions;
create policy whoeats_post_companions_update_tagged
on public.whoeats_post_companions
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Tag invitations where I have not posted yet.
create or replace function public.list_pending_meal_tags(p_limit int default 20)
returns table (
  source_post_id uuid,
  meal_group_id uuid,
  inviter_name text,
  inviter_icon_path text,
  place_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.post_id as source_post_id,
    p.meal_group_id,
    coalesce(u.name, u.user_code, 'ユーザー') as inviter_name,
    u.icon_path as inviter_icon_path,
    coalesce(pl.name, case when p.post_type = 'home' then '自宅' else '外食' end) as place_name
  from public.whoeats_post_companions c
  join public.whoeats_posts p on p.id = c.post_id
  join public.whoeats_users u on u.id = p.user_id
  left join public.whoeats_places pl on pl.id = p.place_id
  where c.user_id = auth.uid()
    and c.joined_post_id is null
    and p.deleted_at is null
    and p.meal_group_id is not null
    and u.deleted_at is null
  order by c.created_at desc
  limit greatest(p_limit, 1);
$$;

revoke all on function public.list_pending_meal_tags(int) from public;
grant execute on function public.list_pending_meal_tags(int) to authenticated;

commit;
