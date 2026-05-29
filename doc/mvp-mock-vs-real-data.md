# MVP: 実データ vs モック（残タスク）

Who eats のダッシュボードで、**Supabase 実データ**と**意図的にモックのまま**の領域を一覧にしたドキュメントです。  
実装の切り分け判断や PR レビュー時に参照してください。

---

## 凡例

| 記号 | 意味 |
|------|------|
| ✅ | Supabase / 外部 API の実データ |
| 🟡 | 一部のみ実データ（残りは固定値・プレースホルダ） |
| 🔶 | **意図的にモックのまま**（DB 未整備・仕様未確定） |

---

## ✅ 実データ（Supabase / Google）

| 画面・機能 | データソース | 未ログイン時 |
|------------|--------------|--------------|
| ホームフィード | `whoeats_posts` + Storage 画像、いいね/コメント件数 | `visibility = public` の投稿のみ |
| マップピン（投稿済み店） | `whoeats_posts` / `whoeats_places` | 同上 |
| 店舗詳細・投稿一覧 | Supabase + Google Places（キーあり時） | public 投稿のみ |
| 友達一覧 | RPC `get_my_friends`（**相互フォローのみ**） | 空（要ログイン） |
| 友達候補・フォロー返し | RPC `get_friend_recommendations` / `get_incoming_friend_requests` / `get_outgoing_pending_follows` | 空 |
| 「友達になる」フロー | `whoeats_follows` INSERT → `is_friends` で相互判定 | 要ログイン |
| プロフィール（名前・ID・bio・アイコン） | `whoeats_users` | ゲスト表示 |
| プロフィール（友達数） | 相互フォロー数 | 0 |
| プロフィール（投稿グリッド） | 自分の `whoeats_posts` 画像 + **ピン留め**（`whoeats_profile_pins`） | 空 |
| お気に入り投稿 | `whoeats_post_favorites` + 設定「お気に入りの投稿を見る」 | 要ログイン |
| 記録（連続日数・今月の投稿日） | `streak_days` + 当月 `whoeats_posts` | ログイン促しメッセージ |
| 通知 | RPC `list_inbox_notifications`（いいね・コメント） | 空 |
| 店舗オートコンプリート | Google Places API | Google のみ（失敗時は空） |

**友達の定義**: フォロー/フォロワー数は使わない。**相互フォロー（`is_friends`）だけが「友達」**。

### 友達になるフロー（実装済み）

1. **「友達になる」** → `whoeats_follows` に自分→相手の 1 行を INSERT
2. **相手がすでに自分をフォロー済み** → その時点で `is_friends` が true → **友達一覧**へ
3. **相手がまだフォローしていない** → **承認待ち**（`get_outgoing_pending_follows`）に表示
4. **相手からフォローされている** → **フォローされています**（`get_incoming_friend_requests`）に表示 → フォロー返しで友達化

UI ラベル: `友達` / `友達になる` / `承認待ち`（`FriendCandidate.actionLabel`）

---

## 🔶 意図的にモックのまま（このままで OK）

### 1. 記録タブ — カロリー・タンパク質・AI 栄養提案

| 項目 | 現状 | 理由 |
|------|------|------|
| `caloriesAvg` | 常に `0` | 栄養集計用テーブル・API が未実装（[TASK-P1-32](phase1/assignments/TASK-P1-32-record-nutrition-ai.md) 相当） |
| `proteinAvg` | 常に `0` | 同上 |
| `aiSuggestion` | 投稿件数ベースの短文のみ | LLM / 栄養分析パイプライン未接続 |
| カレンダー日別の詳細パネル | UI 上の軽いプレースホルダ | [calendar_record_view.dart](../lib/src/features/dashboard/presentation/widgets/calendar_record_view.dart) コメント参照 |

**実データになっている部分**: `streak_days`、今月に投稿があった日（`monthlyShots`）。

**実装する場合の目安**: `meal_nutrition_daily` 等のテーブル設計 → 集計 RPC → `RecordSummary` 接続。

---

### 2. 「からむで探す」— おすすめタグ

| 項目 | 現状 | 理由 |
|------|------|------|
| タグチップ（グルメ・カフェ巡り・ラーメン…） | [FriendSearchPage](../lib/src/features/dashboard/presentation/pages/app_shell_page.dart) 内の **固定 `const` リスト** | タグマスタ・ユーザー嗜好 API が未実装 |
| タップ時の絞り込み | 未接続（`onSelected: (_) {}`） | 同上 |

**実データになっている部分**: 「共通の友達が多い人」「候補一覧」は Supabase RPC 由来。

**実装する場合の目安**: タグテーブル or プロフィール嗜好カラム → 検索 API → `FilterChip` にバインド。

---

## 🟡 ハイブリッド（参考）

| 項目 | 実データ | モック/固定 |
|------|----------|-------------|
| 記録タブ全体 | 連続日数・投稿日 | カロリー・タンパク質・AI 文案 |
| からむで探す | 候補ユーザー一覧 | おすすめタグ行 |

---

## Supabase を使わないビルド

`AppConfig.hasSupabase == false` のときのみ、[mock_dashboard_data_source.dart](../lib/src/features/dashboard/data/datasources/mock_dashboard_data_source.dart) にフォールバックします（ローカル開発・UI 確認用）。

---

## 関連ファイル

| 用途 | パス |
|------|------|
| 実データ（ソーシャル） | `lib/src/features/dashboard/data/datasources/supabase_social_data_source.dart` |
| 実データ（マップ・店投稿） | `lib/src/features/dashboard/data/datasources/supabase_map_pins_data_source.dart` |
| Repository 切替 | `lib/src/features/dashboard/data/repositories/dashboard_repository_impl.dart` |
| DB スキーマ | `supabase/migrations/0001_init.sql` |
| 未ログイン読取・友達 RPC | `supabase/migrations/202605280001_anon_read_and_social_rpc.sql` |
| 友達申請 RPC | `supabase/migrations/202605280002_friend_follow_pending_rpc.sql` |
| ピン留め・お気に入り | `supabase/migrations/202605280007_profile_pins_and_post_favorites.sql` |
| **スプリント1 タスク表** | [sprint-1-active-20260529.md](./sprint-1-active-20260529.md) |

---

## 更新履歴

- 2026-05-29: ピン留め・お気に入りを ✅ に追記。スプリント1タスク表リンク追加
- 2026-05-28: 初版（実データ化後の残モック整理）
