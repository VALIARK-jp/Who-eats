# スプリント1 — やること一覧（2026-05-29 定例版）

> **目的**: リリース可能な MVP（iOS / TestFlight）まで詰める  
> **公式フェーズ**: Phase 1（5/22）の延長。次マイルストーン **Phase 2 = 6/5（中間発表・見せ方）**  
> **参照**: [sprint-1-release-scope.md](./sprint-1-release-scope.md)（背景） / [phase1/TASKS.md](./phase1/TASKS.md)（個票辞書）

---

## 0. プロダクト方針（このスプリントで固定）

| 決定 | 内容 |
|------|------|
| **友達のみ** | 「友達」= **相互フォロー**（`is_friends`）。フォロワー/フォロー中 **数・一覧は作らない** |
| **P1-15 廃止** | フォロー/フォロワー一覧タスクは **Cancelled** |
| **友達申請** | 片方向フォロー → 返しで友達化。DB は既存 `whoeats_follows` + RPC。**UI・用語・導線を「友達申請」として整える** |
| **DB 変更** | **PM のみ**（migration / RLS / RPC） |
| **Web / Vercel** | スプリント1対象外（認証リダイレクトが重い）。**iOS 先行** |
| **並行レーン** | PM = 実機必須・API 接続 / メンバー = アイコン・UI・文言・手順書（Mac 不要） |

---

## 1. スプリント1の期間・完了条件

| 項目 | 目安 |
|------|------|
| **開始** | 2026-05-29（定例） |
| **機能フリーズ** | 2026-06-03（金） |
| **TestFlight** | 2026-06-05 までに 1 本以上 |
| **6/5** | Phase 2 = デモシナリオ・UI polish（P2-01〜） |

### Definition of Done

- [ ] 下表 **Must** がすべて ✅ または「スプリント2へ明記除外」で合意済み
- [ ] **D1〜D4**（アイコン・テーマ・UIv2差分・文言）がドキュメント or Figma に残っている
- [ ] **R1〜R8**（コアフロー）を **実機2名**でチェックリスト合格
- [ ] `supabase migration list` がリモートと一致
- [ ] TestFlight ビルド 1 本以上

---

## 2. すでに実装済み（やること = 実機 QA のみ）

| ID | 機能 |
|----|------|
| R1 | 登録 / ログイン / ログアウト |
| R2 | カメラ → 店候補 → 外食投稿 |
| R3 | 自宅投稿（`post_type=home`） |
| R4 | ホームフィード表示 |
| R5 | マップ・店詳細・Google Places（キー設定は別タスク） |
| R6 | 相互フォロー＝友達・候補・おすすめ |
| R7 | プロフィール編集（名前 / user_code / bio / アイコン） |
| R8 | ピン留め（自分・最大3）/ お気に入り（他人） |
| — | 初回プロフィール設定（P1-11） |
| — | 公開範囲選択（public / friends / private） |
| — | 通知一覧の骨格（RPC `list_inbox_notifications`） |

---

## 3. やること一覧（タスク表）

**優先度**: **Must** = スプリント1必須 / **Should** = 余力で / **Could** = スプリント2可  
**担当**: **PM** / **Member** / **QA**（実機1名） / **Both**

### A. デザイン・ブランド（Member 並行 / PM 承認）

| ID | タスク | 優先度 | 担当 | 状態 | 成果物 |
|----|--------|--------|------|------|--------|
| D1 | アプリアイコン確定 | Must | Member → PM承認 | ❌ | 1024px マスター + export 方針 |
| D2 | 全体テーマ（トークン1枚） | Must | Member | ❌ | 色・角丸・余白・影（`AppTheme` 整合） |
| D3 | UIv2 差分リスト | Should | Member | ❌ | 画面別 Before/After 箇条書き |
| D4 | 文言・コピー確定 | Must | Member + PM | 🟡 | ログイン・投稿・空状態・エラー・利用規約 URL |

### B. ソーシャル — 友達申請（P1-15 代替）

| ID | タスク | 優先度 | 担当 | 状態 | 内容 |
|----|--------|--------|------|------|------|
| FR-1 | 用語統一 | Must | PM | 🟡 | 「フォロー」→ **友達申請 / 申請中 / 承認**（`FriendCandidate.actionLabel` 等） |
| FR-2 | 申請一覧の導線 | Must | PM | 🟡 | 友達タブ or ベル近くに **incoming 件数** → `get_incoming_friend_requests` |
| FR-3 | 申請中一覧の見せ方 | Should | PM | 🟡 | `get_outgoing_pending_follows` を **「送信した申請」** として表示 |
| FR-4 | 申請取り消し | Could | PM | ❌ | outgoing の follow DELETE（任意） |
| ~~P1-15~~ | ~~フォロー/フォロワー一覧~~ | — | — | **Cancelled** | 友達のみ方針 |

**既存 RPC（新規 migration 不要）**: `get_incoming_friend_requests`, `get_outgoing_pending_follows`, `followUser`

### C. 投稿・フィード（PM）

| ID | タスク | P1 | 優先度 | 担当 | 状態 |
|----|--------|-----|--------|------|------|
| F-1 | いいねトグル | P1-04 | Must | PM | ❌ 件数のみ |
| F-2 | コメント 一覧/投稿/削除 | P1-03 | Must | PM | ❌ |
| F-3 | 投稿後 streak RPC | 003 | Must | PM | ❌ `bump_user_streak_on_post` 未呼び出し |
| F-4 | 投稿削除（自分のみ） | P1-18 | Should | PM | ❌ |
| F-5 | 投稿失敗リトライ | P1-10 | Should | PM | ❌ |
| F-6 | フィード ★4.5 固定の解消 | — | Should | PM | 🟡 実 `rating` 表示 or 非表示 |
| F-7 | 投稿評価入力（1–5） | — | Could | PM | ❌ |
| F-8 | 外食/自炊バッジ | P1-27 | Could | PM/Member | ❌ |
| F-9 | タイムライン scope UI | P1-33 / 004 | Could | PM | ❌ → **スプリント2で合意可** |

### D. 記録タブ（PM）

| ID | タスク | P1 | 優先度 | 担当 | 状態 |
|----|--------|-----|--------|------|------|
| REC-1 | 日別パネル実データ化 | P1-16 | Must | PM | ❌ 店名・回数が固定モック |
| REC-2 | 記録 → 投稿詳細遷移 | P1-17 | Should | PM | ❌ |
| REC-3 | 栄養・AI | P1-32 | — | — | **スプリント2**。「準備中」表示で統一 |

### E. 友達・検索（PM）

| ID | タスク | P1 | 優先度 | 担当 | 状態 |
|----|--------|-----|--------|------|------|
| S-1 | `@user_code` 検索接続 | P1-06 | Should | PM | ❌ 入力欄のみ |
| S-2 | からむタグ行 | — | — | — | **スプリント2**（const モックのまま） |
| S-3 | 他ユーザープロフィール | — | Could | PM | ❌ SnackBar のみ |
| S-4 | ブロック UI | P1-14 | Could | PM | **スプリント2** |

### F. 通知（PM）

| ID | タスク | P1 | 優先度 | 担当 | 状態 |
|----|--------|-----|--------|------|------|
| N-1 | 友達申請を通知一覧に載せる | P1-28 一部 | Should | PM | 🟡 |
| N-2 | 未読・タップ遷移完成 | P1-28 | Could | PM | **スプリント2可** |

### G. インフラ・リリース（PM + QA）

| ID | タスク | 優先度 | 担当 | 状態 |
|----|--------|--------|------|------|
| I-1 | iOS Bundle ID 確定 | Must | PM | ❌ `TODO.md` |
| I-2 | GCP Maps キー（iOS 制限） | Must | PM | ❌ |
| I-3 | 実機で地図表示確認 | Must | QA | ❌ |
| I-4 | TestFlight / 署名 | Must | PM | ❌ |
| I-5 | Android キー | Could | PM | iOS 先行なら後回し |
| I-6 | Map backend API URL 本番差替 | Could | PM | スプリント2可 |

### H. 横断・品質（Member + PM）

| ID | タスク | P1 | 優先度 | 担当 | 状態 |
|----|--------|-----|--------|------|------|
| Q-1 | 実機 QA チェックリスト | — | Must | QA | ❌ R1〜R8 |
| Q-2 | ビルド手順書 | T7 | Should | Member | ❌ |
| Q-3 | 状態 UI 統一 | P1-09 | Could | Member | 主要画面後 |
| Q-4 | 小さな UI PR（余白・theme） | T1 | Should | Member | 挙動不変＋スクショ |
| Q-5 | 6/5 デモシナリオ 3 分版 | P2-05 | Should | Both | 定例で骨だけ決める |

---

## 4. 週次イメージ（PM と Member の並行）

```
5/29 定例 ─ 本 MD で Must 確定・担当割当
5/29〜5/31 ─ PM: F-1,F-2,F-3 / FR-1,FR-2 ｜ Member: D1,D2,D4 ｜ QA: 手順書下書き
6/1〜6/3 ─ PM: REC-1,REC-2 / I-1〜I-4 ｜ Member: D3,Q-4 ｜ QA: R1〜R8 全走
6/5 ─ Phase2: デモ・UI polish（P2-01〜）
```

---

## 5. メンバー5人への振り方（Mac 不要）

| 人 | スプリント1タスク例 |
|----|---------------------|
| 1 | D1 アイコン案 3 つ |
| 2 | D2 テーマトークン1枚 |
| 3 | D3 UIv2 差分リスト |
| 4 | D4 文言（空状態・エラー） |
| 5 | Q-2 ビルド手順 + Q-4 小 UI PR |

**ルール**: PR は **挙動不変 + スクショ1枚 + analyze**。DB・migration に触らない。

---

## 6. スプリント2へ回す（定例で触れない）

- 同行者・meal_group（P1-29 / migration 005）
- タイムライン scope フル（P1-33）※ Must にしない場合
- 栄養・AI（P1-32）
- 興味タグ・からむタグ
- Web / Vercel
- ブロック UI（P1-14）
- 他ユーザープロフィール
- お知らせ完成（P1-28 フル）
- `place_stats_daily`
- 共通コンポーネント（P2-07）

---

## 7. 5/29 定例アジェンダ（30分）

1. **5分** — 本 MD の Must（F-1,2,3 / FR-1,2 / REC-1 / D1,4 / I-1〜4）に異論ないか
2. **10分** — Member 5人に D1〜D4 / Q-2 / Q-4 を割当
3. **5分** — QA 担当1名固定 + R1〜R8 チェックリスト担当
4. **5分** — P1-15 Cancelled・友達申請（FR）の説明
5. **5分** — 6/5 デモで見せる画面 3 つ決める

---

## 8. 関連ドキュメント

| 用途 | パス |
|------|------|
| 実装済み vs モック | [mvp-mock-vs-real-data.md](./mvp-mock-vs-real-data.md) |
| Phase1 個票 | [phase1/TASKS.md](./phase1/TASKS.md) |
| ~~P1-15~~ | [TASK-P1-15-follow-lists.md](./phase1/assignments/TASK-P1-15-follow-lists.md)（**実施しない**） |
| 友達 RPC | `supabase/migrations/202605280002_friend_follow_pending_rpc.sql` |
| Maps / キー | [TODO.md](../TODO.md) |
| **PM 一括実装・選別** | [sprint-1-implementation-backlog.md](./sprint-1-implementation-backlog.md) |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-05-29 | 初版。P1-15 廃止・友達申請（FR）追加。Must/Should 整理 |
