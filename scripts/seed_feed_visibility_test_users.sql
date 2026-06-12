-- Feed visibility QA seed for main user 134fc8a8-41ba-4403-92a2-11662b494600
-- 3 relationships x 3 visibilities (friends / near / public)
-- Idempotent: removes prior @vis_test_* rows before insert.

begin;

do $$
declare
  main_uid constant uuid := '134fc8a8-41ba-4403-92a2-11662b494600';
  bridge_uid constant uuid := 'a1000000-0000-4000-8000-000000000001';
  place_id constant uuid := '00000000-0000-4000-8000-000000000001';
  shared_image constant text := 'vis_test_seed/shared.png';

  test_user_ids uuid[] := array[
    'a1000000-0000-4000-8000-000000000011'::uuid,
    'a1000000-0000-4000-8000-000000000012'::uuid,
    'a1000000-0000-4000-8000-000000000013'::uuid,
    'a1000000-0000-4000-8000-000000000021'::uuid,
    'a1000000-0000-4000-8000-000000000022'::uuid,
    'a1000000-0000-4000-8000-000000000023'::uuid,
    'a1000000-0000-4000-8000-000000000031'::uuid,
    'a1000000-0000-4000-8000-000000000032'::uuid,
    'a1000000-0000-4000-8000-000000000033'::uuid
  ];

  test_post_ids uuid[] := array[
    'b1000000-0000-4000-8000-000000000011'::uuid,
    'b1000000-0000-4000-8000-000000000012'::uuid,
    'b1000000-0000-4000-8000-000000000013'::uuid,
    'b1000000-0000-4000-8000-000000000021'::uuid,
    'b1000000-0000-4000-8000-000000000022'::uuid,
    'b1000000-0000-4000-8000-000000000023'::uuid,
    'b1000000-0000-4000-8000-000000000031'::uuid,
    'b1000000-0000-4000-8000-000000000032'::uuid,
    'b1000000-0000-4000-8000-000000000033'::uuid
  ];
begin
  delete from public.whoeats_post_images
  where post_id = any(test_post_ids);

  delete from public.whoeats_posts
  where id = any(test_post_ids)
     or user_id = any(test_user_ids)
     or user_id = bridge_uid;

  delete from public.whoeats_follows
  where follower_id = any(test_user_ids || array[bridge_uid, main_uid])
     or following_id = any(test_user_ids || array[bridge_uid, main_uid]);

  delete from public.whoeats_users
  where id = any(test_user_ids)
     or id = bridge_uid;

  insert into public.whoeats_users (id, user_code, name, email, default_visibility)
  values (
    bridge_uid,
    '@vis_test_bridge',
    'VIS橋渡し友達',
    'vis_test_bridge@who-eats.test',
    'friends'
  );

  insert into public.whoeats_users (id, user_code, name, email, default_visibility) values
    ('a1000000-0000-4000-8000-000000000011', '@vis_test_fr_f', 'VIS友達・友達', 'vis_test_fr_f@who-eats.test', 'friends'),
    ('a1000000-0000-4000-8000-000000000012', '@vis_test_fr_n', 'VIS友達・友達の友達', 'vis_test_fr_n@who-eats.test', 'near'),
    ('a1000000-0000-4000-8000-000000000013', '@vis_test_fr_p', 'VIS友達・公開', 'vis_test_fr_p@who-eats.test', 'public'),
    ('a1000000-0000-4000-8000-000000000021', '@vis_test_ff_f', 'VIS友達の友達・友達', 'vis_test_ff_f@who-eats.test', 'friends'),
    ('a1000000-0000-4000-8000-000000000022', '@vis_test_ff_n', 'VIS友達の友達・友達の友達', 'vis_test_ff_n@who-eats.test', 'near'),
    ('a1000000-0000-4000-8000-000000000023', '@vis_test_ff_p', 'VIS友達の友達・公開', 'vis_test_ff_p@who-eats.test', 'public'),
    ('a1000000-0000-4000-8000-000000000031', '@vis_test_ot_f', 'VISそれ以外・友達', 'vis_test_ot_f@who-eats.test', 'friends'),
    ('a1000000-0000-4000-8000-000000000032', '@vis_test_ot_n', 'VISそれ以外・友達の友達', 'vis_test_ot_n@who-eats.test', 'near'),
    ('a1000000-0000-4000-8000-000000000033', '@vis_test_ot_p', 'VISそれ以外・公開', 'vis_test_ot_p@who-eats.test', 'public');

  insert into public.whoeats_follows (follower_id, following_id) values
    (main_uid, bridge_uid),
    (bridge_uid, main_uid),
    (main_uid, 'a1000000-0000-4000-8000-000000000011'),
    ('a1000000-0000-4000-8000-000000000011', main_uid),
    (main_uid, 'a1000000-0000-4000-8000-000000000012'),
    ('a1000000-0000-4000-8000-000000000012', main_uid),
    (main_uid, 'a1000000-0000-4000-8000-000000000013'),
    ('a1000000-0000-4000-8000-000000000013', main_uid),
    (bridge_uid, 'a1000000-0000-4000-8000-000000000021'),
    (bridge_uid, 'a1000000-0000-4000-8000-000000000022'),
    (bridge_uid, 'a1000000-0000-4000-8000-000000000023');

  insert into public.whoeats_posts (
    id, user_id, place_id, post_type, visibility, caption, rating, visited_at, created_at
  ) values
    ('b1000000-0000-4000-8000-000000000011', 'a1000000-0000-4000-8000-000000000011', place_id, 'restaurant', 'friends',
     '[VIS-TEST T01] 関係=友達 / 公開=友達 / 期待: 友達○ 友達の友達○ 全体○', 4, now(), now() - interval '9 minutes'),
    ('b1000000-0000-4000-8000-000000000012', 'a1000000-0000-4000-8000-000000000012', place_id, 'restaurant', 'near',
     '[VIS-TEST T02] 関係=友達 / 公開=友達の友達 / 期待: 友達○ 友達の友達○ 全体○', 4, now(), now() - interval '8 minutes'),
    ('b1000000-0000-4000-8000-000000000013', 'a1000000-0000-4000-8000-000000000013', place_id, 'restaurant', 'public',
     '[VIS-TEST T03] 関係=友達 / 公開=公開 / 期待: 友達○ 友達の友達○ 全体○', 4, now(), now() - interval '7 minutes'),
    ('b1000000-0000-4000-8000-000000000021', 'a1000000-0000-4000-8000-000000000021', place_id, 'restaurant', 'friends',
     '[VIS-TEST T04] 関係=友達の友達 / 公開=友達 / 期待: 友達× 友達の友達× 全体×', 4, now(), now() - interval '6 minutes'),
    ('b1000000-0000-4000-8000-000000000022', 'a1000000-0000-4000-8000-000000000022', place_id, 'restaurant', 'near',
     '[VIS-TEST T05] 関係=友達の友達 / 公開=友達の友達 / 期待: 友達× 友達の友達○ 全体×', 4, now(), now() - interval '5 minutes'),
    ('b1000000-0000-4000-8000-000000000023', 'a1000000-0000-4000-8000-000000000023', place_id, 'restaurant', 'public',
     '[VIS-TEST T06] 関係=友達の友達 / 公開=公開 / 期待: 友達× 友達の友達× 全体○', 4, now(), now() - interval '4 minutes'),
    ('b1000000-0000-4000-8000-000000000031', 'a1000000-0000-4000-8000-000000000031', place_id, 'restaurant', 'friends',
     '[VIS-TEST T07] 関係=それ以外 / 公開=友達 / 期待: 友達× 友達の友達× 全体×', 4, now(), now() - interval '3 minutes'),
    ('b1000000-0000-4000-8000-000000000032', 'a1000000-0000-4000-8000-000000000032', place_id, 'restaurant', 'near',
     '[VIS-TEST T08] 関係=それ以外 / 公開=友達の友達 / 期待: 友達× 友達の友達× 全体×', 4, now(), now() - interval '2 minutes'),
    ('b1000000-0000-4000-8000-000000000033', 'a1000000-0000-4000-8000-000000000033', place_id, 'restaurant', 'public',
     '[VIS-TEST T09] 関係=それ以外 / 公開=公開 / 期待: 友達× 友達の友達× 全体○', 4, now(), now() - interval '1 minute');

  insert into public.whoeats_post_images (post_id, storage_path, display_order)
  select p.id, shared_image, 0
  from public.whoeats_posts p
  where p.id = any(test_post_ids);
end $$;

commit;
