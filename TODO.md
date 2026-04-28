# TODO

## Google Maps API key setup (pending Bundle ID)

- [ ] iOS の Bundle ID を確定する
- [ ] GCP で iOS 用 API キー制限を `iOS apps` で設定する
- [ ] iOS 制限に確定した Bundle ID を登録する
- [ ] `.env` の `WHOEATS_IOS_MAPS_API_KEY` に iOS 用 Maps API キーを設定する
- [ ] 実機またはシミュレータで地図表示を確認する

## Android key setup

- [ ] Android 用 API キー制限を `Android apps` で設定する
- [ ] package name と SHA-1 を登録する
- [ ] `.env` の `WHOEATS_ANDROID_MAPS_API_KEY` に Android 用 Maps API キーを設定する
- [ ] Android 実機またはエミュレータで地図表示を確認する

## Map backend API wiring

- [ ] `WHOEATS_MAP_PINS_API_URL` を本番または検証環境URLに差し替える
- [ ] `WHOEATS_PLACE_DETAIL_API_TEMPLATE` を本番または検証環境URLに差し替える
- [ ] `.env`（`.env.example` から作成）を設定し、`flutter run` でAPI接続動作を確認する
