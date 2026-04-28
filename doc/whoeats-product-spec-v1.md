# Who eats

## プロダクト仕様書 v1.0（初期構想）

> 本ドキュメントは初期構想の整理用です。  
> 仕様は今後の検討により変更される可能性があります。

## 1. プロダクト概要

### 1.1 コンセプト

「友達の食体験で店を選ぶグルメマップアプリ」

既存のグルメサービス（Google Maps・食べログ）は「知らない人の評価」に依存している。  
Who eatsでは、以下の投稿をベースに信頼できる食体験を地図上で可視化する。

- 友達
- 同じコミュニティ（大学・地域）
- 実際に行った人

### 1.2 キャッチコピー案

- 知らない星5より、友達の一枚
- 店じゃなく、人で選ぶ
- 友達の"うまい"が地図になる

## 2. ターゲット

- 大学生（メイン）
- 若年層（18〜25歳）
- 外食頻度が高い人
- SNSを日常的に使う人

### 2.1 MVPで最短で解く課題

- 大学生が「知らない人の高評価」ではなく「つながりのある人の食体験」で店を選べる状態を作る

### 2.2 MVP成功指標（KPI）

- ダウンロード数: 3,000人
- 週1回以上利用するアクティブユーザー率: 50%以上

## 3. コア価値

- 従来: 評価が高い店
- Who eats: 信頼できる人が行った店

## 4. システム構成

- Google Maps / Places API
  - 店情報・地図・検索
- 自社DB
  - 投稿・ユーザー・フォロー・リアクション・統計

## 5. 機能一覧

### 5.1 地図機能

- 現在地表示
- 店舗ピン表示
- ホットスポット表示（色で可視化）

### 5.2 店検索

- キーワード検索
- カテゴリ検索（ラーメン・カフェ等）
- 近くの店取得

### 5.3 店舗詳細

- 店情報（Google API）
- 投稿一覧
- 行った人数
- 友達の訪問履歴

### 5.4 投稿機能

- 写真投稿
- 店紐付け
- コメント
- 評価
- 自炊投稿（店なし）

#### 投稿項目の必須/任意

- 必須: 写真
- 任意: テキスト（コメント）、評価

#### 投稿時の店舗決定フロー（固定）

- 外食投稿では、撮影時の位置情報から近傍店舗を自動判定し、第一候補の店舗を初期選択する
- 初期選択が誤っている場合、ユーザーは店舗を検索・手動変更できる
- 店舗候補が取得できない場合は、ユーザーが手動で店舗を選択する
- 自炊投稿は位置情報判定を使わず、ユーザーが「自炊」を明示選択して投稿する

### 5.5 タイムライン

- 友達の投稿表示
- 写真中心UI
- リアクション・コメント

### 5.6 フォロー機能

- ユーザーをフォロー
- フォロワー管理
- 投稿の優先表示
- ユーザー検索は `@user_code` で実行する

#### 関係性の定義

- 友達: 相互フォロー関係にあるユーザー
- 近い人: 友達の友達（2ホップ）および友達の友達の友達（3ホップ）までのつながりユーザー
- 全体: アプリをインストールしている全ユーザー

### 5.7 ホットスポット機能

- 今人気の店を表示
- 投稿数・増加率ベース

## 6. データ構造

### 6.1 設計方針

- DBは Supabase Postgres を採用する
- 画像実体は Supabase Storage に保存し、DBには `storage_path` を保存する
- 閲覧制御はRLSを前提に `public / friends / private` を投稿単位で管理する
- 監査・再集計を考慮し、論理削除（`deleted_at`）を基本とする

### 6.2 テーブル一覧（MVP）

- `users`: ユーザープロフィール、公開設定、連続投稿日数
- `follows`: フォロー関係（相互フォロー判定の基礎）
- `blocks`: ブロック関係
- `places`: Google Places由来の店舗情報（投稿起点で永続化）
- `posts`: 投稿本体（店/自炊、公開範囲、本文、評価）
- `post_images`: 投稿画像メタ情報（Storageパス）
- `post_reactions`: 投稿リアクション
- `post_comments`: 投稿コメント
- `place_stats_daily`: 店舗統計（日次集計）

### 6.3 テーブル詳細

#### users

- `id` uuid pk（`auth.users.id` と一致）
- `user_code` text unique not null（アプリ内で表示するユニークID。例: `@maki_1234`）
- `name` text not null
- `email` text unique not null
- `icon_path` text null
- `bio` text null（プロフィール自由記述）
- `default_visibility` text not null default `friends`（`public/friends/private`）
- `streak_days` int not null default 0
- `last_posted_on` date null
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()
- `deleted_at` timestamptz null

制約:
- `default_visibility in ('public','friends','private')`
- `user_code` は `@` 始まりの英数字/`_` を許可（重複不可）
- `bio` は最大160文字

#### follows

- `follower_id` uuid not null
- `following_id` uuid not null
- `created_at` timestamptz not null default now()

制約:
- pk: (`follower_id`, `following_id`)
- `follower_id <> following_id`

#### blocks

- `blocker_id` uuid not null
- `blocked_id` uuid not null
- `created_at` timestamptz not null default now()

制約:
- pk: (`blocker_id`, `blocked_id`)
- `blocker_id <> blocked_id`

#### places

- `id` uuid pk default gen_random_uuid()
- `google_place_id` text unique not null
- `name` text not null
- `address` text null
- `latitude` double precision not null
- `longitude` double precision not null
- `category` text null
- `source` text not null default `google`
- `place_status` text not null default `active`（`active/closed/not_found/inactive`）
- `business_status` text null（Google Placesの営業状態）
- `last_verified_at` timestamptz null
- `verify_fail_count` int not null default 0
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()

運用ルール（固定）:
- 投稿で使われた店舗のみ `places` に永続保存（upsert）する
- 検索で閲覧されただけの店舗は永続保存しない（必要時のみ短期キャッシュ）

制約:
- `source in ('google','manual')`
- `place_status in ('active','closed','not_found','inactive')`

#### posts

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
- `post_type = 'restaurant'` の場合は `place_id` 必須

#### post_images

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

#### post_reactions

- `post_id` uuid not null
- `user_id` uuid not null
- `reaction_type` text not null default `like`
- `created_at` timestamptz not null default now()

制約:
- pk: (`post_id`, `user_id`, `reaction_type`)

#### post_comments

- `id` uuid pk default gen_random_uuid()
- `post_id` uuid not null
- `user_id` uuid not null
- `body` text not null
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()
- `deleted_at` timestamptz null

#### place_stats_daily

- `place_id` uuid not null
- `stat_date` date not null
- `post_count` int not null default 0
- `reaction_count` int not null default 0
- `unique_user_count` int not null default 0
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()

制約:
- pk: (`place_id`, `stat_date`)

### 6.4 主要インデックス

- `posts(user_id, created_at desc)` タイムライン本人表示
- `posts(place_id, created_at desc)` 店詳細表示
- `posts(visibility, created_at desc)` 公開範囲フィルタ
- `follows(following_id)` フォロワー一覧
- `post_images(post_id, display_order)` 投稿画像取得
- `place_stats_daily(stat_date, post_count desc)` ホットスポット算出

### 6.5 RLSの基本方針（MVP）

- `users`: 本人更新可、公開プロフィールはselect可
- `follows`/`blocks`: 本人が作成・削除可
- `posts`: 閲覧は可視性 + ブロック関係で制御
- `post_images`: `posts` の閲覧権限に従属させる
- `post_comments`/`post_reactions`: 閲覧可能な投稿にのみ作成可

## 7. UI構成（最重要）

### 7.0 UIデザイン方針（固定）

- 投稿フォーマットは BeReal の体験を参考にし、「今撮った写真」を主役にしたシンプル構成とする
- 地図画面は BeReal の世界観を参考に、余白・配色・タイポグラフィで洗練された雰囲気を重視する
- ただし UI/アイコン/配色は完全コピーを避け、Who eats 独自のブランドトーンで実装する
- 情報過多を避け、1画面1目的（見る・選ぶ・投稿する）を徹底する

### 7.1 ホーム（マップ画面）

**機能**

- 地図表示
- 店ピン表示
- ホット度（色で表示）

**UI**

- [検索バー]
- 🔥 今ホット
- 📍 近くで人気
- 🧑‍🎓 大学周辺
- 地図（ピン表示）

**見た目の方向性**

- 地図の視認性を優先し、装飾は最小限にする
- ピンの色・形で状態を判別できるようにし、テキスト説明への依存を減らす
- 写真カードやボトムシートは角丸・余白を活かし、軽く上品な印象に統一する

### 7.2 店舗詳細画面

- 店名
- 評価
- 写真

👥 この店に行った人

- 友達
- 近い人
- 全体

投稿一覧（写真）

### 7.3 タイムライン

- ユーザー名
- 写真
- 店名
- コメント
- ❤️ リアクション
- 💬 コメント

### 7.4 投稿画面

- 写真アップロード
- 店選択
- コメント
- 評価
- 自炊選択
- 公開範囲選択（投稿ごと）

**見た目の方向性**

- 撮影写真プレビューを最も大きく配置し、入力項目は二次情報として下部にまとめる
- 操作導線は「撮る → 店確認/変更 → 投稿」の3ステップを崩さない
- フォーム要素は最小限にして、投稿完了までのタップ数を抑える

### 7.5 プロフィール

- 投稿一覧
- 行った店
- フォロー一覧
- ユニークユーザーID（`@user_code`）表示
- 自由記述プロフィール（bio）表示

## 8. 情報表示ロジック

### 3層構造

1. 友達
2. 近い人（同大学・地域）
3. 全体

### フィルター

- 友達のみ
- 近い人
- 全体

### 8.1 表示階層の運用定義（MVP）

- 友達: 相互フォローのみ表示
- 近い人: 2〜3ホップのつながりユーザーを表示
- 全体: 全ユーザー投稿を表示

## 9. ホットスコア

```text
hot_score =
投稿数 × 0.5
+ 増加率 × 0.3
+ リアクション数 × 0.2
```

> 期間窓・最低投稿数・連投上限などの詳細パラメータは、MVPでは固定せず運用観察後に調整する。

## 10. MVP開発範囲

### 必須

- 地図表示
- 店取得（API）
- 投稿
- タイムライン
- フォロー
- 店詳細
- ブロック機能
- 投稿削除機能
- 公開範囲設定（デフォルト + 投稿ごと上書き）
- 連続投稿日数の可視化
- 自炊投稿を肯定的にフィードバックするUI/文言

### 不要（後回し）

- 予約機能
- 決済
- レコメンドAI
- 混雑情報
- 高度なランキング

## 11. 差別化

| 要素 | Who eats | 他サービス |
| --- | --- | --- |
| 評価基準 | 人（友達） | 数値 |
| 投稿 | リアル体験 | レビュー |
| 地図 | ○ | ○ |
| SNS性 | ◎ | △ |

## 12. 初期拡散戦略

- 店ベースで閲覧可能
- ホット表示
- 大学フィルタ
- おすすめユーザー提示

## 13. 将来拡張

- AIレコメンド
- 食の好み分析
- 一緒に行く人マッチング
- 食生活ログ
- 健康連携

## 15. モデレーション・公開設定・継続モチベーション

### 15.1 モデレーション/安全性（MVP）

- ブロック機能を実装する
- ユーザー自身が投稿削除できる
- 公開範囲は「デフォルト設定」と「投稿ごとの設定」の両方を提供する

### 15.2 継続モチベーション

- 連続投稿日数（ストリーク）をプロフィールや投稿導線で表示する
- ストリーク拡張として、`連続自炊日` と `朝食投稿日` をバッジ表示する
- バッジは達成を促す目的で使い、未達成時のペナルティ表示は行わない
- 自炊投稿には、達成感を促すポジティブなリアクション/文言を用意する
- 友達チャレンジ機能を導入し、例として「今週3回自炊」のような軽量共同目標を提供する

## 16. 法務・規約メモ（要件化前提）

- Google Places関連データの保持・表示ポリシーを遵守する
- 画像投稿に関する利用規約（著作権・不適切投稿・削除対応）を明記する
- 年齢層に応じたポリシー（未成年利用を含む）を明記する

## 17. 利用ツール・API要件（MVP）

### 17.1 クライアント/開発ツール

- モバイルアプリ: Flutter（iOS / Android）
- 地図表示: Google Maps SDK（Flutter plugin）
- 画像アップロード: Supabase Storage（`supabase_flutter`）
- 通知: Supabase Realtime / Push通知はMVP後半で判断
- 分析: PostHog または Firebase Analytics（イベント計測）

### 17.2 バックエンド/インフラ

- API方式: REST API（JSON）
- 認証: JWTベース（Apple ID / LINE / メールアドレスログイン）
- データベース: Supabase Postgres
- 画像保存: Supabase Storage
- サーバー処理: Supabase Edge Functions（必要箇所のみ）
- ログ監視: Supabase Logs（最低限のエラーログ収集）

#### 認証実装メモ（pedal_share再現）

- Apple IDログイン: Supabase Edge Function経由でネイティブトークン検証を行う
- LINEログイン: Supabase Edge Function経由でIDトークン検証を行う
- メールアドレスログイン: Supabase Auth（メールリンクまたはパスワード）を利用する
- 初回ログイン時は `users` レコードをupsertしてプロフィール初期値を作成する
- 本プロジェクトの認証実装は `pedal_share` の運用方針を再現する

### 17.3 外部API（必須）

- Google Places API
  - 用途: 店検索、店舗詳細、`google_place_id` の取得
  - 運用: 投稿起点で保存済み店舗はDB優先で返し、未保存時のみGoogle APIを呼ぶ
- Google Maps Platform
  - 用途: 地図描画、位置ベース表示
  - 運用: Who eats独自ピン（友達訪問/投稿あり/ホット）は自前DB集計で描画する

### 17.4 自社API一覧（MVP）

- `POST /auth/signup`
  - メールアドレスユーザー登録
- `POST /auth/login`
  - メールアドレスログイン（トークン発行）
- `POST /auth/apple`
  - Apple IDログイン
- `POST /auth/line`
  - LINEログイン
- `GET /places/search?q=&lat=&lng=&category=`
  - 店舗検索
- `GET /places/{placeId}`
  - 店舗詳細（外部API情報 + 自社投稿統計）
- `POST /posts`
  - 投稿作成（写真必須、テキスト/評価任意、公開範囲含む）
- `DELETE /posts/{postId}`
  - 投稿削除（本人のみ）
- `GET /timeline?scope=friends|near|all`
  - タイムライン取得
- `POST /follows/{userId}`
  - フォロー
- `DELETE /follows/{userId}`
  - フォロー解除
- `GET /users/search?query=@abc`
  - `user_code` 前方一致でユーザー検索
- `POST /users/{userId}/block`
  - ユーザーブロック
- `DELETE /users/{userId}/block`
  - ブロック解除
- `GET /hotspots?lat=&lng=&radius=`
  - ホットスポット取得
- `GET /users/{userId}/streak`
  - 連続投稿日数の取得

### 17.5 API共通ルール

- 認証方式: `Authorization: Bearer <token>`
- レスポンス形式: JSON（`data`, `error` を基本構造とする）
- 日付時刻: ISO 8601（UTC）で統一
- ページング: タイムライン・検索APIは `cursor` 方式を採用
- 公開範囲: `public` / `friends` / `private` を投稿単位で保持
- 画像URL: 永続公開URLは保存せず、必要時に署名URLを生成して返す

### 17.6 計測イベント（KPI追跡）

- `app_install`
- `signup_completed`
- `post_created`
- `weekly_active_user`
- `timeline_viewed`
- `streak_updated`

## 18. Supabase Storage運用要件（pedal_share方式準拠）

### 18.1 バケット設計

- `post-images`（private）: 投稿画像（一覧・詳細で利用）
- `profile-images`（publicまたはprivate）: プロフィール画像
- バケットはMVP段階では増やしすぎず、用途単位で分ける

### 18.2 パス命名規則

- 基本形式: `{user_id}/{category}/{timestamp}_{uuid}.jpg`
- 例: `a1b2.../posts/1714020000_550e8400-e29b-41d4-a716-446655440000.jpg`
- RLSで `storage.foldername(name)[1] = auth.uid()::text` を使用し、他人ディレクトリへの書き込みを禁止する

### 18.3 アクセス制御（RLS）

- `post-images` は private を前提にする
- INSERT/UPDATE: 認証済みユーザーが `auth.uid()` 配下のみ許可
- SELECT: タイムライン可視性（`public` / `friends` / `private`）を満たす投稿に紐づく画像のみ許可
- DELETE: 投稿所有者本人、または運営管理者のみ許可

### 18.4 クライアントアップロード要件

- 投稿画像はクライアント側で圧縮してからアップロード
  - 推奨: 長辺 1280px、JPEG品質 80 前後
- 1投稿あたり最大枚数: MVPでは 1〜4 枚で運用（初期値は1枚）
- 実装は `supabase.storage.from('post-images').upload(path, file)` を採用
- DBには画像の実URLではなく `storage_path` を保存する

### 18.5 配信方式（署名URL）

- 画像表示時に都度 `createSignedUrl(path, expiresIn)` を生成する
- 署名URLの有効期限は短め（例: 1時間）
- クライアントは署名URL期限切れ時に再取得を行う

### 18.6 投稿削除とファイル削除の整合

- 投稿削除APIで、DBレコード削除とStorage削除を同一ユースケースとして扱う
- 実装方針:
  - 第一候補: Edge Functionで「権限確認 → DB削除 → Storage削除」を一括実行
  - 代替案: DBから論理削除後に非同期ジョブでStorage削除
- 孤児ファイル（DB参照なし）を定期クリーンアップするバッチを用意する

### 18.7 コスト/容量運用

- 監視指標:
  - バケット総容量
  - 月間転送量（egress）
  - 画像1枚あたり平均サイズ
- 閾値アラートを設定し、超過時は圧縮率や上限枚数を調整する

### 18.8 セキュリティ・運用ガード

- MIME typeと拡張子の検証を行う
- 画像サイズ上限（例: 10MB）をサーバー側でも検証する
- 不正アップロード対策としてファイル名をユーザー入力値で受け取らない
- 管理者ロールは `auth.jwt()->'app_metadata'->>'role'` で判定する

## 19. 要件定義（実装向け）

### 19.1 機能要件（MVP）

#### FR-01 認証・アカウント

- Apple ID / LINE / メールアドレスの3方式でログインできる
- 初回ログイン時に `users` を自動作成し、`@user_code` を自動発行する
- `@user_code` は一意で、ユーザー検索・プロフィール導線の主キーとして扱う

#### FR-02 投稿作成

- 写真は必須、本文/評価は任意で投稿できる
- 投稿種別は `restaurant` / `home` を選べる
- 公開範囲は `public/friends/private` を投稿ごとに設定できる
- 外食投稿では位置情報から店舗を自動初期選択し、ユーザーが手動変更できる
- 自炊投稿では店舗選択を必須にしない

#### FR-03 投稿削除

- 投稿者本人は自分の投稿を削除できる
- 削除時は投稿本体と画像の整合を保つ（論理削除 + Storage連動削除）
- 削除後はタイムライン・店詳細・プロフィール一覧から非表示になる

#### FR-04 タイムライン/閲覧

- タイムラインは `friends / near / all` で切替表示できる
- `friends` は相互フォローのみ、`near` は2〜3ホップ、`all` は全体投稿を対象とする
- ブロック関係があるユーザーの投稿は相互に表示しない

#### FR-05 フォロー/ブロック

- ユーザーはフォロー/解除できる
- 相互フォローを「友達」判定に使う
- ブロック/解除ができ、ブロック相手の投稿・プロフィール導線を制御する

#### FR-06 地図・店舗

- 地図はGoogle Mapsを表示し、Who eats独自ピンを重ねる
- 店詳細では店舗情報、投稿一覧、行った人数を表示する
- 投稿された店舗のみ `places` に永続保存し、店情報取得はcache-firstで行う

#### FR-07 継続モチベーション

- 連続投稿日数（ストリーク）を日次更新・表示する
- `連続自炊日` / `朝食投稿日` をバッジ表示する
- 友達チャレンジ（例: 今週3回自炊）を作成・参加できる

#### FR-08 検索

- ユーザー検索は `@user_code` 前方一致で行う
- 店舗検索はGoogle Places連携で行い、投稿文脈のある店舗を優先表示できる

### 19.2 API化（Edge Functions / RPC）する処理

- 投稿作成（推奨）: 画像保存 + posts/post_images 作成 + ストリーク更新
- 投稿削除（必須）: 権限確認 + posts論理削除 + post_images論理削除 + Storage削除
- ホットスポット取得（推奨）: 日次集計テーブルを用いた算出ロジック
- ストリーク更新（推奨）: 日跨ぎ判定を含む整合性処理

### 19.3 Supabase直アクセスでよい処理

- places検索/取得（外部API連携済みデータの参照）
- フォロー/ブロックの単純CRUD
- 自分のプロフィール更新
- 閲覧系の単純select（RLSで閉じられるもの）

### 19.4 店舗データ保存ポリシー（固定）

- 永続保存対象: 投稿作成時に参照された店舗のみ（`places` に upsert）
- 非永続対象: 検索結果で一時表示されただけの店舗
- 店詳細取得: `places` を先に参照し、未保存または情報不足時のみGoogle Places APIを呼ぶ
- 地図ピン取得: 基本は `places` + 投稿/集計テーブルから返し、Google APIを毎回のピン描画に使わない
- 短期キャッシュを導入する場合はTTLを設ける（目安: 7〜30日）
- 店舗再検証: `places` 登録済み店舗を月1回Google Placesへ照会し、`business_status` と `last_verified_at` を更新する
- 再検証実行方式: 一括実行ではなく分割バッチ（例: 日次で1/30ずつ）を推奨する
- `not_found` 時の扱い: 即削除せず `place_status = 'not_found'` に更新し、投稿・履歴表示は維持する
- 再試行方針: `not_found` は次回検証で再照会し、連続失敗時に `inactive` へ遷移する
- UI方針: `closed/not_found/inactive` の店舗は「閉業」「情報確認中」などの状態表示を行う

### 19.5 非機能要件（MVP）

- 可用性: 主要画面（地図/タイムライン）は常時利用可能
- 性能: タイムライン初回応答 p95 500ms 目標（画像配信除く）
- セキュリティ: すべてのテーブルでRLS有効化
- 監査: 投稿作成/削除、ブロック操作の実行ログを保持
- 運用: ストレージ容量・転送量・孤児ファイル件数を月次確認
- 運用: `places` の再検証ジョブ成功率、`not_found` 件数、`inactive` 遷移件数を月次監視する

## 14. 本質

- 店を探すアプリではない
- 人を通して店を選ぶアプリ
