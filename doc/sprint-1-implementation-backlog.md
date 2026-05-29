# スプリント1 — PM 一括実装バックログ（選別用）

> **用途**: あなたが **main（または作業ブランチ）で未実装を一気に進める**前に、**やる / やらない** を選ぶリスト  
> **選び方**: 各項目の `[ ] やる` にチェック。`推奨` 列を参考に、まず **Wave 1〜3** だけ通してから大物を判断  
> **関連**: [sprint-1-active-20260529.md](./sprint-1-active-20260529.md)（スプリント全体）

---

## 使い方

1. 下の **選別サマリ表** で `[ ] やる` を付ける
2. **やらない** にしたものは理由を1行メモ（定例で共有）
3. **実装順** は §2 の Wave 順が依存関係的に安全
4. 1 Wave 終わるたびに `dart analyze` + 実機で該当フローだけ確認

**凡例**


| 記号        | 意味                         |
| --------- | -------------------------- |
| **DB**    | migration / RPC が要る（PM のみ） |
| **実機**    | iPhone 必須                  |
| S / M / L | 工数目安（1人・集中作業）              |


---

## 1. 選別サマリ（ここにチェック）

### A. コア機能（コード）


| やる   | ID        | 機能                             | 推奨  | 工数  | DB     | 個票       |
| ---- | --------- | ------------------------------ | --- | --- | ------ | -------- |
| [ ✅] | **F-3**   | 投稿後 `bump_user_streak_on_post` | ✅ 先 | S   | 済      | 003      |
| [ ✅] | **F-1**   | いいねトグル                         | ✅ 先 | M   | 済      | P1-04    |
| [✅ ] | **F-2**   | コメント 一覧/投稿/削除                  | ✅ 先 | M   | 済      | P1-03    |
| [ ✅] | **FR-1**  | 友達申請 用語統一                      | ✅ 先 | S   | 不要     | —        |
| [ ✅] | **FR-2**  | 友達申請 バッジ・導線                    | ✅ 先 | S   | 不要     | —        |
| [ ✅] | **REC-1** | 記録タブ 日別実データ                    | ✅ 先 | M   | 不要     | P1-16    |
| [ ✅] | **REC-2** | 記録 → 投稿詳細                      | ✅ 先 | S   | 不要     | P1-17    |
| [✅ ] | **F-6**   | フィード ★4.5 固定を解消                | ✅ 先 | S   | 不要     | —        |
| [ ✅] | **S-1**   | `@user_code` 検索                | 余力  | M   | 要検討    | P1-06    |
| [✅ ] | **FR-3**  | 送信した申請一覧 UI                    | 余力  | S   | 不要     | —        |
| [ ✅] | **FR-4**  | 申請取り消し                         | 余力  | S   | 不要     | —        |
| [ ✅] | **F-4**   | 投稿削除（論理削除）                     | 余力  | M   | 済      | P1-18    |
| [ ✅] | **F-5**   | 投稿失敗リトライ                       | 余力  | M   | 不要     | P1-10    |
| [ ✅] | **F-7**   | 投稿評価 1–5 入力・表示                 | 余力  | M   | 不要     | —        |
| [ ✅] | **F-8**   | 外食/自炊バッジ                       | 余力  | S   | 不要     | P1-27    |
| []   | **N-1**   | 通知に友達申請系                       | 余力  | M   | 要検討    | P1-28 一部 |
| [ ✅] | **REC-3** | 栄養・AI「準備中」統一                   | 余力  | S   | 不要     | P1-32    |
| [✅ ] | **F-9**   | タイムライン friends/near/all        | 後   | L   | 済004   | P1-33    |
| [✅ ] | **P1-29** | 同行者タグ + meal_group             | 後   | L   | 済005   | P1-29    |
| [✅ ] | **S-3**   | 他ユーザープロフィール                    | 後   | L   | 不要     | —        |
| [✅ ] | **S-4**   | ブロック UI                        | 後   | M   | 済      | P1-14    |
| [ ]  | **N-2**   | 通知 未読・タップ遷移                    | 後   | M   | 要検討    | P1-28    |
| [ ]  | **S-2**   | からむおすすめタグ                      | 後   | L   | **新規** | —        |
| [ ]  | **Q-3**   | 状態 UI 統一 loading/empty         | 後   | L   | 不要     | P1-09    |


### B. インフラ・リリース（コード以外）


| やる  | ID      | 内容              | 推奨  | 備考                    |
| --- | ------- | --------------- | --- | --------------------- |
| [ ] | **I-1** | Bundle ID 確定    | ✅   | `TODO.md`             |
| [ ] | **I-2** | iOS Maps API キー | ✅   | GCP                   |
| [ ] | **I-4** | TestFlight      | ✅   | 署名                    |
| [ ] | **I-5** | Android キー      | 後   | iOS 先行なら省略可           |
| [ ] | **I-6** | Map backend URL | 後   | 今は Google+Supabase で可 |


### C. デザイン素材（実装というより成果物）


| やる  | ID     | 内容          | 備考                     |
| --- | ------ | ----------- | ---------------------- |
| [ ] | **D1** | アプリアイコン     | 1024 + iOS export      |
| [ ] | **D2** | テーマトークン1枚   | `AppTheme` 反映          |
| [ ] | **D4** | 文言・利用規約 URL | `AppConfig` / SnackBar |


### D. 明示スキップ（チェック不要）


| ID                  | 理由                           |
| ------------------- | ---------------------------- |
| ~~P1-15~~           | フォロー/フォロワー一覧 — **Cancelled** |
| Web/Vercel          | 認証リダイレクト — スプリント2            |
| `place_stats_daily` | スコープ外                        |
| P1-32 栄養AI 本実装      | テーブル未接続 — REC-3 の「準備中」で足りる   |


---

## 2. 推奨実装順（Wave）

依存が少ない順。**チェックした項目だけ**各 Wave から拾う。

```
Wave 1 ─ 1日弱 ─ 配線だけ・UI文言
  F-3, FR-1, FR-2, F-6, REC-3

Wave 2 ─ 2〜3日 ─ ソーシャル核心
  F-1, F-2

Wave 3 ─ 1〜2日 ─ 記録タブ
  REC-1, REC-2

Wave 4 ─ 1〜2日 ─ 友達まわり
  S-1, FR-3, FR-4, N-1（任意）

Wave 5 ─ 2日 ─ 投稿 polish
  F-4, F-5, F-7, F-8

Wave 6 ─ 大物（別ブランチ推奨）
  F-9, P1-29, S-3, S-4, N-2, S-2, Q-3
```

---

## 3. 実装メモ（項目別）

### F-3 投稿後 streak RPC ✅ 小

**やること**

- `PostSubmitService.submitPhotoPost` 成功後、または `PostCreationPage._submit` 内で  
`_client.rpc('bump_user_streak_on_post')` を呼ぶ

**触るファイル**

- `lib/src/core/supabase/post_submit_service.dart` または `app_shell_page.dart`（投稿成功後）

**DB**: migration `202605280003` 適用済み想定

---

### F-1 いいねトグル

**やること**

- `FeedPost` に `likedByMe` 追加（`copyWith`）
- `SupabaseSocialDataSource`: 自分の reaction 有無をバッチ取得 or 行 INSERT/DELETE
- `togglePostLike(postId)` → repository → usecase → controller
- `FoodPostCard` / `PostDetailPage` のハートをタップ可能に（楽観更新 + 失敗ロールバック）

**触るファイル**

- `app_entities.dart`, `supabase_social_data_source.dart`, `dashboard_repository.dart`, `dashboard_repository_impl.dart`, `dashboard_usecases.dart`, `app_shell_controller.dart`, `food_post_card.dart`, `app_shell_page.dart`（PostDetail）
- `app.dart`（usecase 注入）

**DB**: `whoeats_post_reactions` + RLS 既存。RPC 不要（PostgREST で可）

**個票**: [TASK-P1-04](./phase1/assignments/TASK-P1-04-reactions.md)

---

### F-2 コメント CRUD

**やること**

- エンティティ `PostComment`（id, userId, userName, body, createdAt）
- 一覧 GET / INSERT / 論理削除 or DELETE（RLS は本人削除のみ）
- `PostDetailPage` 下部に ListView + TextField + 送信

**触るファイル**

- 上記 F-1 と同系 + `PostDetailPage` 専用 widget 抽出推奨

**DB**: `whoeats_post_comments` 既存

**個票**: [TASK-P1-03](./phase1/assignments/TASK-P1-03-comments.md)

---

### FR-1 / FR-2 友達申請 UI

**やること**

- `FriendCandidate.actionLabel`: 「友達になる」→「申請を承認」、「承認待ち」→「申請中」等
- 友達タブ `_FriendsPage` ヘッダーに `incoming.length` バッジ
- SnackBar 文言も「フォロー」→「友達申請」に統一

**触るファイル**

- `app_entities.dart`（actionLabel）
- `app_shell_page.dart`（`_FriendsPage`, `FriendSearchPage`, `_FriendCandidateRow`）

**DB**: 不要（RPC 002 済み）

---

### FR-3 / FR-4 申請中・取り消し

**FR-3**: 既に `FriendSearchPage` に outgoing セクションあり → ラベル整理のみで可  
**FR-4**: `SupabaseSocialDataSource.unfollowUser` / DELETE `whoeats_follows` + UI ボタン

---

### REC-1 記録 日別実データ

**やること**

- `fetchRecordSummary` を拡張するか、日別用 `fetchPostsForDay(DateTime)` を追加
- `calendar_record_view.dart` の固定店名・回数・友達アバターを **当月 posts クエリ**に差し替え

**触るファイル**

- `supabase_social_data_source.dart`, `calendar_record_view.dart`, 必要なら controller

---

### REC-2 記録 → 投稿詳細

**やること**

- 日別リストにサムネタップ → `FeedPost` 構築 → 既存 `_openPostDetail`

**触るファイル**

- `calendar_record_view.dart`, `app_shell_page.dart`（コールバック）

---

### F-6 / F-7 / F-8 評価・バッジ

**F-6**: `FoodPostCard` の `const rating = 4.5` 削除 → `FeedPost.rating` / `createdAt` を entity に追加して feed 取得時に含める、未設定なら非表示  
**F-7**: 投稿シートに 1–5 セレクタ → `PostSubmitService` で `rating` INSERT  
**F-8**: `post_type == home` で Chip「自炊」

---

### F-4 投稿削除

**やること**

- `posts.deleted_at` UPDATE（自分のみ）
- 投稿詳細の自分投稿に削除 → 確認ダイアログ → feed/profile  refresh

**RLS**: 既存ポリシー確認要

**個票**: P1-18

---

### F-5 投稿失敗リトライ

**やること**

- 失敗時 `PostDraft` をローカル保持（`shared_preferences` または controller フィールド）
- ホームにバナー「投稿を再試行」→ 編集シート再開

**個票**: P1-10

---

### S-1 user_code 検索

**やること**

- RPC または `whoeats_users.user_code` の `ilike '@query%'`（RLS で検索可能か要確認）
- `_FriendsPage` の `TextField.onChanged` → debounce → 結果リスト

**DB**: 検索用 RPC が無ければ **008 migration**（PM）

**個票**: P1-06

---

### F-9 タイムライン scope（大）

**やること**

- `fetchHomeFeed(scope: friends|near|all)` 
- `near`: RPC `get_near_feed_user_ids` + posts filter
- UI: `SegmentedButton` on `_FeedTab`

**触るファイル**

- `supabase_social_data_source.dart`, `app_shell_controller.dart`, `app_shell_page.dart`

**個票**: P1-33

---

### P1-29 同行者 + meal_group（大）

**やること**

- 投稿 UI: 友達 `FilterChip` 複数選択
- INSERT `whoeats_post_companions`, `meal_group_id` on post
- タグされた人向け「同じごはんで投稿」バナー

**DB**: migration 005 済み。Flutter 未接続

**個票**: P1-29

---

### S-3 他ユーザープロフィール（大）

**やること**

- 読み取り専用プロフィールページ + 友達申請ボタン
- `_onFriendTap` の SnackBar を Navigator 置換

---

### S-4 ブロック

**やること**

- INSERT/DELETE `whoeats_blocks`
- 投稿詳細 or 友達行の「ブロック」

---

### N-1 / N-2 通知

**N-1**: `list_inbox_notifications` 拡張 or クライアントで incoming 件数を合成表示  
**N-2**: 未読フラグ（ローカル）+ タップで PostDetail / Friends

---

### REC-3 栄養「準備中」

**やること**

- `calendar_record_view.dart` の kcal/タンパク質 UI を「準備中」1行に（0 表示をやめる）

---

### Q-3 状態 UI 統一

**やること**

- `AppStateView` を feed / map / friends / record で統一利用

**個票**: P1-09

---

## 4. PM 一括実装時のブランチ案


| 方式          | 内容                                        |
| ----------- | ----------------------------------------- |
| **1本で全部**   | `feature/sprint1-pm-batch` — コンフリクトリスク高   |
| **Wave ごと** | `feature/wave2-likes-comments` 等 — **推奨** |
| **main 直**  | 個人開発なら可。PR レビューなしなら merge 前に実機全走          |


---

## 5. 実装後チェック（最小）

- `dart analyze lib`
- ログイン → 投稿 → フィード反映
- いいね/コメント（やる場合）
- 友達申請 incoming → 承認 → 友達一覧
- ピン留め / お気に入り（回帰）
- 記録タブ 日別（やる場合）
- `supabase db push` 新 migration があれば

---

## 6. 更新履歴


| 日付         | 内容            |
| ---------- | ------------- |
| 2026-05-29 | PM 一括実装・選別用初版 |


