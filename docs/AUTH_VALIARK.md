# Valiark 認証（Who eats）

Panda Talk と **同じ Supabase プロジェクト・Edge Function・LINE チャンネル**を使う。アプリごとに変えるのは主に **リダイレクト URL** と **プロフィール表**。

## Panda Talk との差分（一覧）

| 項目 | Panda Talk | Who eats |
|------|------------|----------|
| メール / PKCE リダイレクト | `io.valiark.pandatalk://callback` | `io.valiark.whoeats://callback` |
| `.env` キー | `PANDA_TALK_AUTH_REDIRECT_URL` | `WHOEATS_AUTH_REDIRECT_URL` |
| iOS URL scheme | `io.valiark.pandatalk` | `io.valiark.whoeats` |
| iOS LINE scheme | `line3rdp.com.valiark.pandaTalk` | `line3rdp.com.valiark.whoeats` |
| Android intent-filter | `io.valiark.pandatalk` + `host=callback` | `io.valiark.whoeats` + `host=callback` |
| プロフィール表 | `panda_profiles` | `whoeats_users`（`WHOEATS_SUPABASE_PROFILES_TABLE`） |
| ユーザーコード | `@` なし（API 側） | DB 制約で `@` 付き（例: `@yuto`） |
| 初回 UI | `ProfileSetupScreen` | `ProfileSetupPage` |
| ゲスト | オンボーディング後ゲスト可 | ホーム（地図）はゲスト可、他タブはログインゲート |

## 共通（変更不要）

- Supabase URL / anon key（チーム配布）
  - `WHOEATS_SUPABASE_ANON_KEY` は JWT 形式の legacy anon key（`eyJ...`）を使う。
  - `sb_publishable_...` は `line-auth-native` / `apple-auth-native` の `verify_jwt` で `UNAUTHORIZED_INVALID_JWT_FORMAT` になる。
- LINE チャンネル ID: `2010102462`（`valiark_auth_config.dart`）
- Edge Functions: `line-auth-native`, `apple-auth-native`（panda_talk リポからデプロイ可）
- `AuthService` の Edge 呼び出しヘッダー（`Authorization` + `apikey`）
- PKCE + `detectSessionInUri: false` + `ValiarkDeeplinkHandler`

## Supabase Dashboard

**Authentication → URL Configuration → Redirect URLs** に **両方** 登録する:

```text
io.valiark.pandatalk://callback
io.valiark.whoeats://callback
```

## クライアント構成

- `lib/src/features/auth/application/auth_service.dart` — LINE / Apple / メール / Google
- `lib/src/features/auth/presentation/auth_shell_page.dart` — ログイン後プロフィール入力 → `AppShellPage`
- `lib/src/core/supabase/valiark_deeplink_handler.dart` — メール確認リンク受信
- `lib/main.dart` — `LineSDK.instance.setup(valiarkLineChannelId)`

## 手動チェックリスト

1. `.env` に `WHOEATS_AUTH_REDIRECT_URL=io.valiark.whoeats://callback`
2. メール登録 → 確認リンク → Who eats が開く（Panda Talk が開かないこと）
3. LINE / Apple ログイン・新規登録
4. 初回プロフィール（名前・@コード・アイコン・一言）→ タブのゲート解除
5. ゲストでホームは利用可、友達・投稿・記録・プロフィールはオーバーレイ

### Android 追加（LINE / Maps）

- **LINE Login チャンネル `2010102462`** に Android パッケージ `com.valiark.whoeats` と **debug / release の SHA-1** を登録（Panda Talk の `com.pandatalk.panda_talk` だけでは Who eats Android は失敗する）
- **`.env`** の `WHOEATS_ANDROID_MAPS_API_KEY` を設定（Gradle が `android/app/build.gradle.kts` 経由で manifest に注入。プロジェクトルートの `.env` を読む）
- GCP で Maps SDK for Android を有効化し、キー制限に `com.valiark.whoeats` + SHA-1 を登録

```bash
# debug SHA-1（LINE Console / GCP 登録用）
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

詳細運用は Panda Talk の [docs/05_auth.md](https://github.com/valiark/panda_talk/blob/main/docs/05_auth.md) と [valiark_client_secrets_playbook.md](https://github.com/valiark/panda_talk/blob/main/docs/valiark_client_secrets_playbook.md) を参照。
