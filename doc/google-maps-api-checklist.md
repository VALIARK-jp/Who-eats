# Google Maps API ON/OFF Checklist

Who eats の現在実装に合わせた、GCP APIとキー設定のチェックリスト。

## 1) キー構成（推奨）

- [ ] `who-eats-ios-sdk-key` を作成
- [ ] `who-eats-android-sdk-key` を作成
- [ ] `who-eats-webservice-dev-key` を作成（試験用）

## 2) API制限（まずは試験向け）

### iOS SDKキー

- [ ] Maps SDK for iOS: ON
- [ ] Places API: OFF（試験でSDK直呼びしないなら）
- [ ] Directions API: OFF
- [ ] Application restriction: iOS apps
- [ ] Bundle ID を登録

### Android SDKキー

- [ ] Maps SDK for Android: ON
- [ ] Places API: OFF（試験でSDK直呼びしないなら）
- [ ] Directions API: OFF
- [ ] Application restriction: Android apps
- [ ] package name + SHA-1 を登録

### Web Serviceキー（試験）

- [ ] Places API: ON
- [ ] Directions API: ON
- [ ] Application restriction: None（試験時のみ）
- [ ] API restriction: 上記2つのみ

## 3) Flutter側の接続チェック

- [ ] `.env` の `WHOEATS_IOS_MAPS_API_KEY` に iOS SDKキーを設定
- [ ] `.env` の `WHOEATS_ANDROID_MAPS_API_KEY` に Android SDKキーを設定
- [ ] `.env` を作成して `WHOEATS_GOOGLE_MAPS_WEB_API_KEY` を設定し、`flutter run` で注入

## 4) 画面機能ごとの期待動作

- [ ] 地図表示（Maps SDK）: マップタイルが表示される
- [ ] 周辺検索（Places Nearby）: 初期ピンが表示される
- [ ] 店舗タップ解決（Nearby by coordinate）: オレンジ店舗タップ付近で place_id 解決
- [ ] 店舗詳細（Place Details）: 店名・住所・電話・営業情報が表示される
- [ ] 店舗画像（Places Photos）: 画像が表示される（無ければプレースホルダ）
- [ ] 入力補助（Autocomplete）: 投稿編集の店名候補が表示される
- [ ] 徒歩分（Directions）: 店舗詳細に徒歩分が表示される（取得できる場合）

## 5) よくあるエラーと対処

### `REQUEST_DENIED`

- [ ] 対象APIが有効化されているか確認
- [ ] 使っているキーが正しいか確認（SDKキー / Web Serviceキーの取り違え）
- [ ] API制限に必要APIが含まれているか確認
- [ ] Application restriction が厳しすぎないか確認

### 地図は出るが詳細が出ない

- [ ] Web Serviceキーが `WHOEATS_GOOGLE_MAPS_WEB_API_KEY` に渡っているか確認
- [ ] Places API と Directions API がWeb Serviceキーで許可されているか確認

## 6) 本番前の締め

- [ ] Web Serviceキーの Application restriction を最終方針へ変更（サーバー経由推奨）
- [ ] 不要APIをキー制限から削除
- [ ] 予算アラートを設定
- [ ] 監査用に使用API一覧を記録
