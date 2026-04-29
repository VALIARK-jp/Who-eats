# Who eats DBテーブル設計 確定版（MVP）

> 目的: 班開発でDB変更事故を防ぎつつ、機能単位の実装委譲を可能にする。  
> 方針: **本書をMVP期間の唯一のDB正本（Single Source of Truth）** とする。

---

## 1. ガバナンス（最重要）

- DBテーブル定義（DDL / migration / index / constraint / trigger / RLS）は **PMのみ変更可**。
- メンバーは原則として「既存スキーマ前提」でAPI/画面/テストを実装する。
- スキーマ変更要求は Issue 化し、PMレビュー承認後にのみ反映する。
- `main` 直push禁止。DB関連変更は必ずPRで理由を明記する。

---

## 2. 設計原則

- DB: Supabase Postgres
- 画像実体: Supabase Storage（DBは `storage_path` のみ保持）
- 投稿可視性: `public / friends / private`
- 削除方針: 論理削除（`deleted_at`）
- 店舗保存ポリシー: **投稿で利用された店舗のみ `places` に永続化**
  - MVPでは論理削除を基本とし、クライアントからの物理削除（DELETE）は原則行わない

---

## 3. テーブル一覧（MVP確定）

1. `users`
2. `follows`
3. `blocks`
4. `places`
5. `posts`
6. `post_images`
7. `post_reactions`
8. `post_comments`
9. `place_stats_daily`

---

## 4. テーブル定義（確定）

### 4.1 `users`

- `id` uuid pk（`auth.users.id` と一致）
- `user_code` text unique not null（例: `@maki_1234`）
- `name` text not null
- `email` text unique not null
- `icon_path` text null
- `bio` text null
- `default_visibility` text not null default `friends`
- `streak_days` int not null default 0
- `last_posted_on` date null
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()
- `deleted_at` timestamptz null

制約:
- `default_visibility in ('public','friends','private')`
- `bio` は最大160文字
- `user_code` は `@` 始まりの英数字/`_` のみ

### 4.2 `follows`

- `follower_id` uuid not null
- `following_id` uuid not null
- `created_at` timestamptz not null default now()

制約:
- pk: (`follower_id`, `following_id`)
- `follower_id <> following_id`

### 4.3 `blocks`

- `blocker_id` uuid not null
- `blocked_id` uuid not null
- `created_at` timestamptz not null default now()

制約:
- pk: (`blocker_id`, `blocked_id`)
- `blocker_id <> blocked_id`

### 4.4 `places`

- `id` uuid pk default gen_random_uuid()
- `google_place_id` text unique not null
- `name` text not null
- `address` text null
- `latitude` double precision not null
- `longitude` double precision not null
- `category` text null
- `source` text not null default `google`
- `place_status` text not null default `active`
- `business_status` text null
- `last_verified_at` timestamptz null
- `verify_fail_count` int not null default 0
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()

制約:
- `source in ('google','manual')`
- `place_status in ('active','closed','not_found','inactive')`

### 4.5 `posts`

- `id` uuid pk default gen_random_uuid()
- `user_id` uuid not null
- `place_id` uuid null（自炊投稿時はnull）
- `post_type` text not null（`restaurant/home`）
- `visibility` text not null（`public/friends/private`）
- `caption` text null
- `rating` int null
- `visited_at` timestamptz null
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()
- `deleted_at` timestamptz null

制約:
- `post_type in ('restaurant','home')`
- `visibility in ('public','friends','private')`
- `rating between 1 and 5`（null可）
- `post_type='restaurant'` の場合 `place_id` 必須

### 4.6 `post_images`

- `id` uuid pk default gen_random_uuid()
- `post_id` uuid not null
- `storage_path` text not null
- `display_order` int not null default 0
- `width` int null
- `height` int null
- `created_at` timestamptz not null default now()
- `deleted_at` timestamptz null

制約:
- unique: (`post_id`, `display_order`)

### 4.7 `post_reactions`

- `post_id` uuid not null
- `user_id` uuid not null
- `reaction_type` text not null default `like`
- `created_at` timestamptz not null default now()

制約:
- pk: (`post_id`, `user_id`, `reaction_type`)

### 4.8 `post_comments`

- `id` uuid pk default gen_random_uuid()
- `post_id` uuid not null
- `user_id` uuid not null
- `body` text not null
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()
- `deleted_at` timestamptz null

### 4.9 `place_stats_daily`

- `place_id` uuid not null
- `stat_date` date not null
- `post_count` int not null default 0
- `reaction_count` int not null default 0
- `unique_user_count` int not null default 0
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()

制約:
- pk: (`place_id`, `stat_date`)

---

## 5. 主要FK（確定）

- `follows.follower_id -> users.id`
- `follows.following_id -> users.id`
- `blocks.blocker_id -> users.id`
- `blocks.blocked_id -> users.id`
- `posts.user_id -> users.id`
- `posts.place_id -> places.id`
- `post_images.post_id -> posts.id`
- `post_reactions.post_id -> posts.id`
- `post_reactions.user_id -> users.id`
- `post_comments.post_id -> posts.id`
- `post_comments.user_id -> users.id`
- `place_stats_daily.place_id -> places.id`

---

## 6. 主要インデックス（確定）

- `posts(user_id, created_at desc)`
- `posts(place_id, created_at desc)`
- `posts(visibility, created_at desc)`
- `follows(following_id)`
- `post_images(post_id, display_order)`
- `place_stats_daily(stat_date, post_count desc)`

---

## 7. RLS方針（確定）

- `users`: 本人更新可、公開プロフィールはselect可
- `follows` / `blocks`: 本人が作成・削除可
- `posts`: 可視性 + ブロック関係で閲覧制御
- `post_images`: 投稿の閲覧権限に従属
- `post_comments` / `post_reactions`: 閲覧可能な投稿にのみ作成可
- 友達推薦（共通友達数）/ near(2-hop) など「他人の関係を横断する集計」は、RLSを緩めず **RPC（SECURITY DEFINER）** で提供する（例: `get_friend_recommendations`）

---

## 8. 機能委譲ルール（DB固定で回すため）

- メンバーは「機能ごと」に担当してよい（例: フォロー機能、投稿詳細、コメント機能）。
- ただし前提として **本書のスキーマは固定** とし、テーブル追加・列追加は禁止。
- 必要な変更が出た場合は、`DB変更リクエスト` をPMに提出する。

リクエスト最小フォーマット:
- 背景（何が詰まっているか）
- 追加/変更したい列・型
- 互換性影響（既存API/UIへの影響）
- 代替案（アプリ層吸収で回避できないか）

---

## 9. MVP凍結宣言

- 本書をもってMVPのDB設計を凍結する。
- 凍結解除は PM 判断のみ。
- 解除時は `更新履歴` に「理由・影響・移行手順」を必ず残す。

---

## 10. 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-04-28 | 初版確定（PM専用DB変更ルールを明記） |

