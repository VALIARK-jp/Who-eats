begin;

create table if not exists public.whoeats_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.whoeats_users(id) on delete cascade,
  reported_user_id uuid null references public.whoeats_users(id) on delete cascade,
  reported_post_id uuid null references public.whoeats_posts(id) on delete cascade,
  reason text not null,
  detail text null,
  created_at timestamptz not null default now(),
  constraint whoeats_reports_target_check
    check (
      (reported_user_id is not null and reported_post_id is null)
      or (reported_user_id is null and reported_post_id is not null)
    )
);

create index if not exists idx_whoeats_reports_reporter_created_at
  on public.whoeats_reports (reporter_id, created_at desc);

create index if not exists idx_whoeats_reports_reported_user_created_at
  on public.whoeats_reports (reported_user_id, created_at desc);

create index if not exists idx_whoeats_reports_reported_post_created_at
  on public.whoeats_reports (reported_post_id, created_at desc);

alter table public.whoeats_reports enable row level security;

drop policy if exists whoeats_reports_insert_own on public.whoeats_reports;
create policy whoeats_reports_insert_own
on public.whoeats_reports
for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists whoeats_reports_select_own on public.whoeats_reports;
create policy whoeats_reports_select_own
on public.whoeats_reports
for select
to authenticated
using (reporter_id = auth.uid());

commit;
