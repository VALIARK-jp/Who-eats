begin;

-- Prod repair for the post-submit path.
-- The app uploads post photos to storage.objects and creates places on restaurant posts.
-- These objects existed in the dev-oriented migration history, but prod was missing them.

insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists post_images_storage_select_auth on storage.objects;
create policy post_images_storage_select_auth
on storage.objects
for select
to authenticated
using (bucket_id = 'post-images');

drop policy if exists post_images_storage_insert_own on storage.objects;
create policy post_images_storage_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'post-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists post_images_storage_update_own on storage.objects;
create policy post_images_storage_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'post-images'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'post-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists post_images_storage_delete_own on storage.objects;
create policy post_images_storage_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'post-images'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists places_insert_authenticated on public.whoeats_places;
create policy places_insert_authenticated
on public.whoeats_places
for insert
to authenticated
with check (true);

commit;
