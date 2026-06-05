# 基礎工学 PBL（情報工学 A）— Who eats 班 提出ドキュメント

> **プロダクト名**: Who eats（友達の食体験で店を選ぶグルメマップアプリ）  
> **リポジトリ**: 本プロジェクト（Flutter + Supabase）  
> **最終更新**: 2026-05-28

---

## フォルダ構成

| ファイル | 用途 | CLE 提出 |
|----------|------|----------|
| [00-pbl-course-overview.md](./00-pbl-course-overview.md) | **全体説明**（PBLの意味・社会課題・3条件・評価観点） | 参考 |
| [00-pbl-requirements-summary.md](./00-pbl-requirements-summary.md) | 授業要件の要約（提出物チェックリスト） | 参考 |
| [**who-eats-narrative.md**](./who-eats-narrative.md) | **公式ストーリー**（経緯・偏食・展望） | 発表・レポートの軸 |
| [assignment-1-social-issue.md](./assignment-1-social-issue.md) | **課題1** 一人暮らし・偏食 | レポートに転記 |
| [assignment-2-solution-design.md](./assignment-2-solution-design.md) | **課題2** 解決方法の立案 | レポートに転記 |
| [assignment-3-implementation.md](./assignment-3-implementation.md) | **課題3** 実践・実装状況 | 最終レポートに転記 |
| [**midterm-report.md**](./midterm-report.md) | **中間レポート** 本文ドラフト（班用たたき台） | **PDF 化して提出** |
| [**中間レポート.md**](./中間レポート.md) | **中間レポート**（`中間レポート.docx` から変換） | **PDF 化して提出** |
| [**final-report.md**](./final-report.md) | **最終レポート** 本文ドラフト | **PDF 化して提出** |
| [presentation-midterm.md](./presentation-midterm.md) | ミニ発表会（第7週）5分+5分 | スライド作成用 |
| [presentation-final-poster.md](./presentation-final-poster.md) | ポスター発表会（A4×12枚目安） | 印刷・展示用 |
| [templates/activity-report-todo.md](./templates/activity-report-todo.md) | 週次 TODO リスト雛形 | CLE 掲示板（テキスト） |
| [templates/activity-report-minutes.md](./templates/activity-report-minutes.md) | 週次議事録雛形 | CLE 掲示板（テキスト） |
| [templates/cover-page.md](./templates/cover-page.md) | 表紙用テンプレート | PDF 表紙 |

---

## 提出前チェックリスト

### 中間レポート（第9週開始まで）

- [ ] 表紙：表題「中間レポート」、班名、全員の学籍番号・氏名・OUmail
- [ ] 課題1（背景・意義・既存調査）を記載
- [ ] 課題2（具体化・技術・アプローチ・シナリオ・今後の ToDo・分担）を記載
- [ ] 図表を入れ、引用には出典を明記
- [ ] PDF で CLE 提出（**docx 貼り付け禁止**）

### 最終レポート（最終週の翌週・授業開始時刻まで）

- [ ] 表紙：表題「最終レポート」
- [ ] 課題1・2 の概要
- [ ] システム説明（設計意図、分担、環境構築、動作結果、苦労点、未完了部分）
- [ ] PDF 提出

### その他

- [ ] 毎週：活動報告（TODO + 議事録）を火曜 23:59 までに CLE（テキスト直書き）
- [ ] 最終週：相互評価（4項目×班員投票）
- [ ] GitHub は **プライベートリポジトリ**（公開は授業ルール上相談）

---

## PDF 化の手順（例）

1. `midterm-report.md` / `final-report.md` を VS Code / Typora / Pandoc で PDF 出力  
2. 表紙は Word または `templates/cover-page.md` を先頭に結合  
3. 班員情報を全員分記入してから提出

```bash
# Pandoc がある場合の例
pandoc report/midterm-report.md -o midterm-report.pdf --pdf-engine=xelatex -V documentclass=ltjarticle
```

---

## 関連するプロジェクト内ドキュメント

| パス | 内容 |
|------|------|
| `doc/whoeats-product-spec-v1.md` | プロダクト仕様・課題設定の根拠 |
| `doc/whoeats-screen-spec-v1.md` | 画面仕様 |
| `doc/sprint-1-release-scope.md` | MVP スコープ |
| `doc/team-project-status-and-wbs.md` | 班内 WBS・進捗 |
