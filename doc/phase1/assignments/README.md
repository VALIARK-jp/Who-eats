# Phase 1 メンバー向けタスク個票

> **このフォルダのドキュメントは、非エンジニアのメンバーにも読めるように書いています。**  
> 用語や進め方が分からないときは、まず下の「用語ミニ辞典」と「個票の見出しルール」を読んでから、担当の `TASK-P1-xx-*.md` を開いてください。

> **PM向け・見落とし防止（最重要）**: 仕様の一行が個票に落ちているかは **[SOURCE-TO-TASK-COVERAGE.md](./SOURCE-TO-TASK-COVERAGE.md)** で管理する。配布前・締め前に必ず1通り読み、**GAP 行をゼロにするか、意図的に後回しと理由を書く**。

---

## 用語ミニ辞典（共通）

| 用語 | ひとことで |
|------|------------|
| **リポジトリ** | このアプリのソースコードがまとまっている箱（いま見ているフォルダ一式）。 |
| **PR（ピーアール）** | 変更内容を提出するときの「まとめパッケージ」。1タスクにつき原則1つ作る。 |
| **Flutter** | このアプリを動かしている開発フレームワーク。 |
| **画面（ページ）** | アプリの1枚の画面。 |
| **ウィジェット** | 画面を構成する部品（ボタン・文字・入力欄など）。 |
| **プロパティ（属性）** | 部品に付ける「設定項目」の名前。例: 文字入力欄の **最大文字数**、ボタンの **押したときの色**。エンジニアがコードで指定します。 |
| **API** | アプリがサーバーとデータのやり取りをするときの「窓口」。 |
| **DB / スキーマ** | データの置き場と形。**変更はPMのみ**（メンバーはIssueで相談）。 |

---

## 個票の見出しルール（すべての TASK-P1-xx で共通）

各ファイルは、次の順の見出しでそろえています。

1. **目的** — なぜこの仕事があるか（ユーザーにとっての価値）。
2. **説明** — アプリ上の見え方、用語、前提。
3. **方法** — 非エンジニア向け（文言・確認・仕様の詰め）と、エンジニア向け（実装の進め方）に分けてあります。
4. **確認** — チェックボックス。誰でも最終確認に使えます。
5. **タスク** — 番号付きのやることリスト（細かい順序）。

---

## 使い方（PM・メンバー共通）

- PM は担当者に **このフォルダ内の1ファイル** を指定する（例: 「あなたは `TASK-P1-05-follow.md`」）。
- **1タスク = 1PR** を原則とする（エンジニアがコードを出すとき）。
- 全体の地図は [TASKS.md](../TASKS.md) を読む。
- **PMが先に終わらせること**: [PM-PRE-DISTRIBUTION-IMPLEMENTATION.md](../../pm-only/PM-PRE-DISTRIBUTION-IMPLEMENTATION.md)

---

## 索引（ファイル一覧）

| ID | ドキュメント | 依存の目安 |
|----|----------------|------------|
| P1-01 | [TASK-P1-01-post-api.md](./TASK-P1-01-post-api.md) | PMのみ（配布前） |
| P1-02 | [TASK-P1-02-post-ui.md](./TASK-P1-02-post-ui.md) | PMのみ（最小まで配布前。投稿磨き込みは22〜27、その他画面仕様は28〜34） |
| P1-03 | [TASK-P1-03-comments.md](./TASK-P1-03-comments.md) | 投稿が画面で使えるようになってから |
| P1-04 | [TASK-P1-04-reactions.md](./TASK-P1-04-reactions.md) | 同上 |
| P1-05 | [TASK-P1-05-follow.md](./TASK-P1-05-follow.md) | フォローAPIの説明が `doc/` にあること |
| P1-06 | [TASK-P1-06-user-search.md](./TASK-P1-06-user-search.md) | 05の代替または追加 |
| P1-07 | [TASK-P1-07-profile-edit.md](./TASK-P1-07-profile-edit.md) | 初回プロフィール（11）のあとが望ましい |
| P1-08 | [TASK-P1-08-profile-icon.md](./TASK-P1-08-profile-icon.md) | 07と同時期なら順番をPMと調整 |
| P1-09 | [TASK-P1-09-state-ui.md](./TASK-P1-09-state-ui.md) | **第2波推奨**（主要PRがマージされたあと） |
| P1-10 | [TASK-P1-10-post-retry.md](./TASK-P1-10-post-retry.md) | 投稿作成の画面があること |
| P1-11 | [TASK-P1-11-onboarding-profile.md](./TASK-P1-11-onboarding-profile.md) | ログインが動くこと（PM） |
| P1-12 | [TASK-P1-12-home-two-pane.md](./TASK-P1-12-home-two-pane.md) | ホーム全体のファイルが触れるので他タスクと競合しやすい |
| P1-13 | [TASK-P1-13-place-tabs.md](./TASK-P1-13-place-tabs.md) | 店の画面に投稿が出る状態が望ましい |
| P1-14 | [TASK-P1-14-block.md](./TASK-P1-14-block.md) | 05の近くで着手しやすい |
| P1-15 | [TASK-P1-15-follow-lists.md](./TASK-P1-15-follow-lists.md) | 05のあと |
| P1-16 | [TASK-P1-16-record-data.md](./TASK-P1-16-record-data.md) | 記録用のAPIまたはモック合意 |
| P1-17 | [TASK-P1-17-record-to-post.md](./TASK-P1-17-record-to-post.md) | 16のあと |
| P1-18 | [TASK-P1-18-post-delete.md](./TASK-P1-18-post-delete.md) | 投稿作成があること |
| P1-19 | [TASK-P1-19-bug-triage.md](./TASK-P1-19-bug-triage.md) | 後半 |
| P1-20 | [TASK-P1-20-tests.md](./TASK-P1-20-tests.md) | 後半 |
| P1-21 | [TASK-P1-21-evidence.md](./TASK-P1-21-evidence.md) | 締め |
| P1-22 | [TASK-P1-22-post-caption-validation.md](./TASK-P1-22-post-caption-validation.md) | PMの「投稿できる最小」のあと |
| P1-23 | [TASK-P1-23-post-location-default.md](./TASK-P1-23-post-location-default.md) | 同上 |
| P1-24 | [TASK-P1-24-post-camera-place-polish.md](./TASK-P1-24-post-camera-place-polish.md) | 同上 |
| P1-25 | [TASK-P1-25-post-visibility-ui.md](./TASK-P1-25-post-visibility-ui.md) | 同上 |
| P1-26 | [TASK-P1-26-home-cooking-post-flow.md](./TASK-P1-26-home-cooking-post-flow.md) | PM最小のあと。画面仕様6.7の自炊／外食分岐 |
| P1-27 | [TASK-P1-27-post-type-badges.md](./TASK-P1-27-post-type-badges.md) | 投稿カード等に `post_type` が載ってから |
| P1-28 | [TASK-P1-28-notifications-inbox.md](./TASK-P1-28-notifications-inbox.md) | 通知APIまたはモック合意後 |
| P1-29 | [TASK-P1-29-post-companion-field.md](./TASK-P1-29-post-companion-field.md) | 投稿フローあり。APIフィールド要確認 |
| P1-30 | [TASK-P1-30-map-pin-bottom-sheet.md](./TASK-P1-30-map-pin-bottom-sheet.md) | マップにピンが出たあと |
| P1-31 | [TASK-P1-31-profile-pinned-posts.md](./TASK-P1-31-profile-pinned-posts.md) | DB/APIがピン留めを許す合意後 |
| P1-32 | [TASK-P1-32-record-nutrition-ai.md](./TASK-P1-32-record-nutrition-ai.md) | `P1-16` と併走可。JSON合意後 |
| P1-33 | [TASK-P1-33-timeline-scope-ui.md](./TASK-P1-33-timeline-scope-ui.md) | タイムラインAPIが scope 対応後 |
| P1-34 | [TASK-P1-34-map-friend-pin-3d-fallback.md](./TASK-P1-34-map-friend-pin-3d-fallback.md) | 友達訪問ピンのデータが取れたあと |

---

## 共通の受け入れ基準（提出前に読む）

1. **品質**: `flutter analyze` が通ること（エンジニア作業のとき）。
2. **見える化**: 変更した画面の Before / After のスクショを PR に貼ること。
3. **正直さ**: 仕様と違う変更をしたら、PRの説明文に理由を書くこと。
4. **ルール**: **データベースの形を変える変更は入れない**。必要なら PM に Issue で相談。

---

## いまのコードの入り口（エンジニア向け・2026年時点の例）

実装するときの手がかりとして、リポジトリ内には例えば次があります（ファイルが増えたらPMが更新してよい）。

- アプリ全体の起動: `lib/main.dart` → `lib/src/app.dart`
- ホームの土台（タブやマップの入り口になりやすい）: `lib/src/features/dashboard/presentation/pages/app_shell_page.dart`
- 画面の状態の置き場（例）: `lib/src/features/dashboard/presentation/controllers/app_shell_controller.dart`

個票の「触りがちなファイル」はあくまで例です。**迷ったら PM かエンジニアに聞いてから**触ってください。
