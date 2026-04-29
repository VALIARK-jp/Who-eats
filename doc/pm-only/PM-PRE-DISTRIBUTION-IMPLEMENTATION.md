# PMが配布前に実装しておく内容（チェックリスト）

> 目的: メンバーに `doc/phase1/assignments/` の個票を渡す前に、リポジトリ上で「詰まりどころ」をPMが縦に通す。  
> 関連: [PM-PREREQUISITES-BEFORE-ASSIGN.md](./PM-PREREQUISITES-BEFORE-ASSIGN.md)（前提タスク一覧）・[PM-OWNED-TASKS.md](./PM-OWNED-TASKS.md)

## 完了の定義（メンバー配布のGo）

次がすべて満たせたら、個票配布でよい（厳しめ運用）。

1. **認証**: サインアップ／ログイン／ログアウトが動き、セッション切れ時に落ちず再ログインに辿れる。
2. **DB / RLS**: migration 初版・RLS 最小・seed が入り、メンバーは **スキーマ変更なし** で開発できる。
3. **5コアのうち次の4つが疎通済み**（API＋必要なら Edge／RLS まで。フロントは最低限の画面でよい）:
   - **投稿作成**: 「**投稿できる**」最小（`restaurant` / `home`）。細部の作り込みは [個票索引](../phase1/assignments/README.md) の `P1-22` 以降（投稿系〜画面仕様GAPの `P1-34` まで）に任せる。
   - **タイムライン取得**: visibility + ブロック反映。
   - **店詳細取得**: `places` + 投稿 + 集計。
   - **マップピン取得**: キャッシュ／集計／外部 API の分担どおり。
4. **フォロー／解除**: メンバー実装可。**契約（JSON・エラー形）は先に固定**して `doc/` に置く。
5. **ガードレール**: `.env.example`、PR テンプレ、DB変更はPMのみの周知。
6. **全員環境**: `flutter run` で起動し、認証後に主要画面へ進める。API失敗でクラッシュしない。

## 実装時に触りがちな領域（メモ）

- 投稿最小でも **店 `place_id` 紐付け・Storage・RLS** はここで一度通す。
- メンバー向け個票の **依存**（例: `P1-03` は `P1-02` 相当の投稿UIが存在してから）は [assignments/README.md](../phase1/assignments/README.md) の表を正とする。

## 配布後

- メンバー作業の入口: **`doc/phase1/assignments/README.md`**
- 親一覧・優先度: **`doc/phase1/TASKS.md`**
- **仕様→個票の抜け漏れ防止**: 配布のたびに **`doc/phase1/assignments/SOURCE-TO-TASK-COVERAGE.md`** を更新し、**GAP を残さないか**確認する（残すなら「後回し理由」を同表に書く）。
