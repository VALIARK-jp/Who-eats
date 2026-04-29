# メンバー配布前にPMが終わらせる前提タスク

> 目的: メンバーが機能実装に集中できる状態を先に作る。  
> 方針: ここが終わるまで大きい機能タスクを配布しない。

## 0. 5コアのうち配布前にPMが縦に通す範囲（方針固定）

`doc/task-list-after-core-flows.md` の5フローのうち、次の **4** は **配布前にPMが実装〜疎通まで** 持つ（API契約に加え、ブロッカーを外すため）。

1. **投稿作成** — 「**投稿できる**」ところまで（`restaurant` / `home` の分岐は仕様どおり）。以降のUI・通知・マップ等は **Phase1個票**（`doc/phase1/TASKS.md` と `doc/phase1/assignments/README.md`、`TASK-P1-22` 以降）に分割して配布する。
2. **タイムライン取得** — `public` / `friends` / `private` とブロックを反映した取得。
3. **店詳細取得** — `places` + 投稿 + 集計。
4. **マップピン取得** — キャッシュ・集計・外部APIの分担どおり。

**フォロー／解除**（相互フォロー判定を含む）はこの「4」とは切り離し、**メンバー向けレーン**（例: `P1-05`）として残す。

## A. 認証・認可（PM担当）

1. 認証方式確定（Supabase Auth: email/password など）
2. サインアップ/ログイン/ログアウトの最小フロー実装
3. セッション切れ時の再ログイン導線整備
4. RLS前提のユーザーコンテキスト確認

## B. DB・RLS（PM担当）

5. `db-table-design-final-mvp.md` に沿って migration 初版作成
6. 全テーブルFK/制約/インデックス反映
7. RLSポリシー最小版反映（posts/images/comments/reactions/follows/blocks）
8. seedデータ作成（開発検証用）

> 実体: `supabase/migrations/0001_init.sql`

## C. API契約固定（PM担当）

9. 5コアフローの入出力JSONを確定（**節0の4**は配布前にPM実装まで。フォローは契約のみ先に固定し実装はメンバー可）
10. エラーコード規約（403/404/409/422/500）を固定
11. モックレスポンスを `doc/` に配置

## D. 開発ガードレール（PM担当）

12. 「DB変更はPMのみ」ルールをドキュメント化して周知
13. PRテンプレに必須項目追加（影響範囲/スクショ/テスト）
14. `.env.example` の必須キーを最終確認

## E. 配布判定（Go条件）

15. `flutter run` で最低限の起動確認が全員環境で可能
16. 認証後に主要画面へ遷移できる
17. API失敗時にクラッシュしない
18. メンバー向け配布先（`doc/phase1`, `doc/phase2`）が最新

---

## 配布開始の目安

- 上記18項目のうち、A〜Cを完了した時点で機能タスク配布を開始してよい。
- **厳しめ運用**: 節0の **4フロー疎通**（投稿最小・タイムライン・店詳細・マップピン）まで終えてから、投稿の磨き込み・フォローUIなどをメンバーに振ると手戻りが少ない。
- D/Eは並行で進める。
- メンバー配布の入口: [phase1/assignments/README.md](../phase1/assignments/README.md)。PM 実装チェックリスト: [PM-PRE-DISTRIBUTION-IMPLEMENTATION.md](./PM-PRE-DISTRIBUTION-IMPLEMENTATION.md)。

