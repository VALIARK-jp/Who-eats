# Who eats

友達や信頼できる人の食事投稿が、地図とタイムラインで見られるグルメSNSアプリ。  
「知らない人の星5」ではなく、つながりの中の食体験で店を選ぶ。

- **App Store（iOS）:** https://apps.apple.com/jp/app/who-eats/id6775419615
- **紹介LP:** https://valiark.jp/who-eats/
- **運営:** [VALIARK合同会社](https://valiark.jp/)

## 自分の役割

阪大情報科学科の授業プロジェクト（6人班）の **PM**。以下を主導した。

- PostgreSQL（Supabase）の **テーブル設計・マイグレーション・RLS**
- **認証**（LINE / Apple / メール）と valiark-prod 共有基盤との接続設計
- フロント向け **API / RPC 契約** の整理とレビュー（Clean Architecture の data 層インターフェース）
- スプリント計画・WBS・公開前の PM 専用タスク（DB・認証・Edge Functions）の実装

UI / 3D マップピン等はメンバー担当。DB・認証・ソーシャル API のオーナーは自分。

## 技術スタック

| 領域 | 技術 |
|---|---|
| クライアント | Flutter（iOS / Android） |
| 状態管理 | Provider |
| バックエンド | Supabase（PostgreSQL, Auth, Storage, Edge Functions） |
| 認証 | LINE Login, Sign in with Apple, メール（OTP） |
| 地図 | Google Maps / Places API |
| プッシュ | Firebase Cloud Messaging + Edge Function |
| インフラ | valiark-prod Supabase（PandaTalk 等と共有プロジェクト、`whoeats_*` スキーマ分離） |

## 設計のポイント

### 1. ネットワーク型アプリ向けの可視性設計

投稿の公開範囲を **友達 / 友達の友達 / 全体** の3段階に分け、RLS と RPC でフィード・地図の表示を制御。1人だけ DL しても価値が出にくいため、友達グラフを前提にしたデータモデルにしている。

### 2. マルチアプリ共有 Supabase 上のドメイン分離

VALIARK 自社プロダクト（PandaTalk 等）と **同一 Supabase プロジェクト** を共有しつつ、`whoeats_*` テーブル・RLS ヘルパーで Who eats ドメインを分離。認証 Edge Function・LINE チャネル設計は社内共通基盤を再利用（`docs/AUTH_VALIARK.md` 参照）。

### 3. ソーシャル操作を RPC に集約

フォロー（pending / accepted）、meal tag、ホームフィードスコープ、投稿削除などを **PostgreSQL RPC + RLS** で実装。クライアントは PostgREST 経由で一貫した契約を呼び出す。

## セットアップ

完全なローカル起動には **Supabase プロジェクトへのアクセス** と API キーが必要。リポジトリ単体では本番 DB に接続できない。

```bash
cp .env.example .env
# .env に WHOEATS_SUPABASE_URL, WHOEATS_SUPABASE_ANON_KEY, Maps API キー等を設定

flutter pub get
flutter run
```

- 環境変数の優先順位・秘密情報の扱い: [docs/valiark_client_secrets_playbook.md](docs/valiark_client_secrets_playbook.md)
- マイグレーション: `supabase/migrations/`（`supabase db push` で適用）
- **アーキテクチャ参照:** `doc/whoeats-product-spec-v1.md`, `doc/db-table-design-final-mvp.md`

## リポジトリ構成（抜粋）

```
lib/                 Flutter アプリ（features / core）
supabase/migrations/ PostgreSQL スキーマ・RLS・RPC
supabase/functions/  Edge Functions（push 通知等）
doc/                 プロダクト仕様・DB 設計
```

## ライセンス・公開について

授業プロジェクト起源だが、現在は VALIARK 自社プロダクトとして App Store 公開中。  
GitHub を Public にする場合は、**チームメンバー全員の同意**を事前に取得すること。
