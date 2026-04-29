-- Dev default place (client cannot insert places; seed for MVP post submit)
insert into public.places (id, google_place_id, name, address, latitude, longitude, source)
select
  '00000000-0000-4000-8000-000000000001'::uuid,
  'who_eats_dev_default_place',
  'Dev default place (MVP)',
  'Shibuya, Tokyo',
  35.6595,
  139.7004,
  'manual'
where not exists (
  select 1 from public.places p where p.google_place_id = 'who_eats_dev_default_place'
);

-- Private bucket for post photos
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

-- MVP: allow authenticated users to register places used by their posts.
drop policy if exists places_insert_authenticated on public.places;
create policy places_insert_authenticated
on public.places
for insert
to authenticated
with check (true);
