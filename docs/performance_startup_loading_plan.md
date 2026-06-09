# 起動・読み込みの重さ改善メモ

**目的:** Who eats の「起動が重い」「地図が出るまで遅い」「画像が遅い」を、原因ごとに分解して改善するための作業メモ。  
**前提:** Flutter は「ファイルを順番に読む」というより、`lib/main.dart` を起点に、必要になったクラスや関数を実行時にたどっていく。

---

## 1. まず最初に動く箇所

Flutter アプリが開くと、まず次の順で動く。

1. iOS / Android のネイティブ起動処理
2. Flutter エンジンが Dart 実行を開始
3. [`lib/main.dart`](../lib/main.dart) の `main()`
4. `dotenv.load(fileName: '.env')`
5. Firebase 初期化
6. Supabase 初期化
7. [`WhoEatsApp`](../lib/src/app.dart) の生成
8. [`AppShellController.initialize()`](../lib/src/features/dashboard/presentation/controllers/app_shell_controller.dart) の実行
9. ホーム・地図・プロフィール系のデータ取得

つまり、「最初に読み込まれるファイル」は厳密には 1 つではない。  
実際に遅さの原因になりやすいのは、`main.dart` 直後の初期化処理と、`initialize()` の中で待っているネットワーク処理。

---

## 2. いま重くなりやすい原因候補

### 2.1 起動時に取りすぎている

[`AppShellController.initialize()`](../lib/src/features/dashboard/presentation/controllers/app_shell_controller.dart#L348) は、次を順番に待っている。

- 端末位置の取得
- フィード取得
- 地図ピン取得
- 友達一覧取得
- 記録サマリー取得
- プロフィール概要取得
- 通知取得
- 下書きタグ取得

この構造だと、1つでも遅い API があると、画面全体の初回表示が遅れる。

### 2.2 地図ピン取得が重い

[`DashboardRepositoryImpl.getMapPins()`](../lib/src/features/dashboard/data/repositories/dashboard_repository_impl.dart#L187) は、Supabase のピン取得だけでなく、状況によっては Google Places や map API まで見に行く。

つまり、地図の初回表示は以下のいずれかで遅くなりうる。

- Supabase の `mutualFriendIds` 取得
- Supabase のピン取得
- Google Places の検索
- map API のフォールバック

今後の方針としては、**Supabase に保存された「実際に誰かが使ったピン」をまず返す**。  
Google Places は、DB にピンがないときの補完として扱う方が、Who eats の文脈に合う。

### 2.3 地図の再取得が複数回走る

[`AppShellPage`](../lib/src/features/dashboard/presentation/pages/app_shell_page.dart) では、地図表示時に viewport の再取得が走る。  
特に以下が重なりやすい。

- `initialize()` 内の地図取得
- `GoogleMap.onMapCreated` 内の再取得
- `onCameraIdle` での再取得

### 2.4 画像が全部ネットワーク直読み

画像表示の多くが `Image.network` 直読みになっている。

例:

- [`place_bottom_sheet.dart`](../lib/src/features/dashboard/presentation/widgets/place_bottom_sheet.dart)
- [`app_shell_page.dart`](../lib/src/features/dashboard/presentation/pages/app_shell_page.dart)
- [`profile_food_grid.dart`](../lib/src/features/dashboard/presentation/widgets/profile_food_grid.dart)

これだと、画像ごとのキャッシュ戦略やサムネイル最適化が弱く、一覧表示が重くなる。

---

## 3. どうやって確認するか

### 3.1 まず見るログ

次のログを見れば、どこで待っているかが分かる。

- `lib/main.dart` の `debugPrint`
- `AppShellController.initialize()` の開始・終了ログ
- `getMapPins start`
- `Map created, refreshing viewport pins`
- `getMapPins source=...`

実行例:

```bash
flutter run -v
```

見るべきポイント:

- `main()` が始まった時刻
- `initialize start` から `initialize done` までの差分
- `getMapPins start` から返るまでの時間
- 地図タブを開いた時に `onMapCreated` が何回走るか

### 3.2 ブレークポイントで確認する

IDE で次にブレークポイントを置くと、どこで止まっているか分かる。

- [`lib/main.dart`](../lib/main.dart)
- [`lib/src/app.dart`](../lib/src/app.dart)
- [`AppShellController.initialize()`](../lib/src/features/dashboard/presentation/controllers/app_shell_controller.dart#L348)
- [`DashboardRepositoryImpl.getMapPins()`](../lib/src/features/dashboard/data/repositories/dashboard_repository_impl.dart#L187)
- [`AppShellPage` の `onMapCreated`](../lib/src/features/dashboard/presentation/pages/app_shell_page.dart#L1969)

### 3.3 性能を見る

深掘りするときは次を使う。

- `flutter run --profile`
- Flutter DevTools の Performance タブ
- iOS は Xcode Instruments
- Android は Android Studio Profiler

見るべきもの:

- 起動直後の frame drops
- 画像 decode の集中
- 地図タイル表示までの時間
- API 待ち時間

---

## 4. 改善の優先順位

### 4.1 起動時の同期処理を減らす

`initialize()` で全部待つのをやめる。  
まず画面を出して、後から重いものを段階的に埋める。

候補:

- フィードは先に出す
- 地図ピンは地図タブを開いた時に読む
- 通知・記録サマリー・プロフィール概要は遅延ロードする

実装メモ:

- 先に `feed` を返し、`friends` / `notifications` / `recordSummary` / `profileOverview` / `pendingMealTags` は後追いで埋める形にした
- フィードが表示された直後に地図ピンの取得を非同期で開始し、初回表示を止めずに裏で読ませる
- これで初回の白い待ち画面を短くし、フィード表示を最優先にする

### 4.2 地図の初回ロードを軽くする

候補:

- 初回は Supabase ピンだけ返す
- Google Places は後追いで差し込む
- viewport 再取得を debounce する
- `onMapCreated` と `initialize()` の二重取得を整理する

実装メモ:

- `onMapCreated` の初回 viewport 再取得は外し、`onCameraIdle` は短い debounce をかけてから viewport を再取得するようにした
- 地図タブ表示後も viewport 更新はまとめて実行し、同じ移動で何度も DB/API を叩かないようにした

### 4.3 画像の読み込みを軽くする

候補:

- `Image.network` をキャッシュ付きに置き換える
- 一覧ではサムネイル画像を使う
- 投稿画像は保存時に縮小版も作る
- `cacheWidth` / `cacheHeight` を使う

実装メモ:

- 固定サイズのサムネイルやボトムシート画像に `cacheWidth` を入れて、decode 負荷を少し落とした

### 4.4 画面ごとに遅延読み込みする

候補:

- ホーム初期表示は最低限にする
- マップタブは開いた時に初期化する
- プロフィールの画像グリッドは表示範囲だけ読む

---

## 5. 実装方針

最初にやるべき順番はこれ。

1. `initialize()` を分割して、初回表示を止めないようにする
2. 地図ピン取得の経路を軽くする
3. 画像キャッシュを入れる
4. 再取得の重複を減らす
5. 必要なら `timeline` / `DevTools` で計測して再調整する

---

## 6. すぐ見たいファイル

- [`lib/main.dart`](../lib/main.dart)
- [`lib/src/app.dart`](../lib/src/app.dart)
- [`lib/src/features/dashboard/presentation/controllers/app_shell_controller.dart`](../lib/src/features/dashboard/presentation/controllers/app_shell_controller.dart)
- [`lib/src/features/dashboard/data/repositories/dashboard_repository_impl.dart`](../lib/src/features/dashboard/data/repositories/dashboard_repository_impl.dart)
- [`lib/src/features/dashboard/presentation/pages/app_shell_page.dart`](../lib/src/features/dashboard/presentation/pages/app_shell_page.dart)
- [`lib/src/features/dashboard/presentation/widgets/place_bottom_sheet.dart`](../lib/src/features/dashboard/presentation/widgets/place_bottom_sheet.dart)
- [`lib/src/features/dashboard/presentation/widgets/profile_food_grid.dart`](../lib/src/features/dashboard/presentation/widgets/profile_food_grid.dart)
