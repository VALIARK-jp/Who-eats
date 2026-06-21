# Push 通知の prod 接続手順

このリポジトリの push 通知は次の 2 つをつなぐ構成です。

- クライアントアプリ: `Firebase Messaging` で端末トークンを取得する
- Supabase Edge Function: `send-push` が `whoeats_device_push_tokens` を参照して FCM 送信する

`valiark-prod` で動かすときは、次の 3 箇所を揃える。

## 1. Firebase 側

### クライアント設定

- Firebase Console で `valiark-prod` 用のアプリを作る
`ios/Runner/GoogleService-Info.plist` は dev 用、[`ios/Runner/GoogleService-Info prod.plist`](../ios/Runner/GoogleService-Info%20prod.plist) は prod 用として扱う。

prod の Flutter 実行 / build は `scripts/flutter_run_prod.sh` / `scripts/flutter_build_prod.sh` が自動で plist を差し替える。Xcode で手動実行するときは [`scripts/ios_google_service_info.sh`](../scripts/ios_google_service_info.sh) で `prod` / `dev` を切り替える。

`Firebase.initializeApp(options: ...)` 用の env はこのリポジトリでは必須にしていない。iOS は native plist、Android は platform 側の設定に従う。

### Cloud Messaging

- APNs key を Firebase の Cloud Messaging に登録する
- `valiark-prod` 用の service account JSON を用意する

## 2. Supabase 側

`send-push` Edge Function の secrets を `valiark-prod` に合わせる。

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`

例:

```bash
supabase secrets set \
  SUPABASE_URL=https://<prod-project>.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=<service_role> \
  FCM_PROJECT_ID=<firebase-project-id> \
  FCM_SERVICE_ACCOUNT_JSON='<service-account-json>'
```

`./scripts/valiark-prod-supabase-setup.sh functions` で `send-push` を prod にデプロイできる。

## 3. クライアント側

- `.env` に `WHOEATS_SUPABASE_URL` と `WHOEATS_SUPABASE_ANON_KEY` を prod 用にする
- iOS の `GoogleService-Info.plist` は prod 用に差し替える（dev/prod は上記スクリプトで切り替え）
- Android を Firebase Console の別アプリとして使う場合は、`android/app/build.gradle.kts` の `applicationId` をその package 名に合わせる

## 4. 動作確認

1. アプリを起動してログインする
2. 端末トークンが `whoeats_device_push_tokens` に登録されることを確認する
3. Supabase の `send-push` を叩いて通知が届くことを確認する
4. iOS は実機で APNs 経由の到達を確認する

## 5. 24時間投稿リマインド（`send-post-reminders`）

最終投稿から24時間経過したユーザーへ、友達・公開ユーザーの最新投稿者名を含む push を送る。

- Edge Function: `send-post-reminders`
- DB: `202606180001_post_reminder_push.sql`（`last_posted_at` / RPC）
- 認証: `CRON_SECRET` または service role key（`x-cron-secret` ヘッダー可）

### secrets

`send-push` と同じ FCM secrets に加え、任意で cron 用 secret を設定する。

```bash
supabase secrets set CRON_SECRET='<random-secret>'
```

### デプロイ

```bash
./scripts/valiark-prod-supabase-setup.sh functions
```

`send-post-reminders` は JWT 検証なし（`--no-verify-jwt`）。`CRON_SECRET` または service role で保護する。

### 定期実行（1時間ごと推奨）

Supabase Dashboard → Edge Functions → `send-post-reminders` → Schedules で cron を設定する。

- Schedule: `0 * * * *`（毎時0分）
- HTTP method: POST
- Headers: `x-cron-secret: <CRON_SECRET>`

手動テスト:

```bash
curl -X POST "https://<project>.supabase.co/functions/v1/send-post-reminders" \
  -H "x-cron-secret: <CRON_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10}'
```

dev / prod 両方で migration を push したうえで、Functions と Schedule をそれぞれ設定する。
