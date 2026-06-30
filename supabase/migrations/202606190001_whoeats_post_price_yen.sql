begin;

alter table public.whoeats_posts
  add column if not exists price_yen integer null;

alter table public.whoeats_posts
  drop constraint if exists whoeats_posts_price_yen_check;

alter table public.whoeats_posts
  add constraint whoeats_posts_price_yen_check
  check (price_yen is null or price_yen >= 0);

comment on column public.whoeats_posts.price_yen is
  '食事の金額（円）。任意入力。';

commit;
