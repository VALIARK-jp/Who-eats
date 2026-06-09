## Supabase migrations

このフォルダは Supabase のDBスキーマ（DDL / index / RLS）を管理する。

- 正本: `doc/db-table-design-final-mvp.md`
- 初版: `supabase/migrations/0001_init.sql`

### valiark-prod（prod / release）

Who eats の prod は `valiark-prod` に link して管理する。

- 手順の正本: [docs/16_valiark_prod_who_eats_setup.md](../docs/16_valiark_prod_who_eats_setup.md)
- DB: `./scripts/valiark-prod-supabase-setup.sh db`
- Edge Functions: `./scripts/valiark-prod-supabase-setup.sh functions`
- 共有秘密: [docs/valiark_client_secrets_playbook.md](../docs/valiark_client_secrets_playbook.md)

### 運用ルール（MVP）

- DB変更（DDL / migration / index / constraint / trigger / RLS）は **PMのみ**。
- メンバーはスキーマ変更が必要なら Issue で相談。

### CLI でリモートにマイグレーションを載せる（履歴つき）

前提: [Supabase CLI](https://supabase.com/docs/guides/cli) が入っていること（例: `brew install supabase/tap/supabase`）。

1. **ログイン**（ブラウザが開く）

   ```bash
   supabase login
   ```

2. **プロジェクトをリンク**（ダッシュボード → Project Settings → General の **Reference ID** を使う）

   ```bash
   cd "/Users/makiyuto/dev/Who_eats"
   supabase link --project-ref <YOUR_PROJECT_REF>
   ```

3. **リモートの Postgres メジャーバージョンと一致させる**  
   SQL Editor で `select version();` などを実行し、`supabase/config.toml` の `[db] major_version` が一致しているか確認する。

4. **マイグレーションをプッシュ**（`supabase_migrations` に適用履歴が残る）

   ```bash
   supabase db push
   ```

5. **確認**（任意）

   ```bash
   supabase migration list
   ```

### prod の push 通知連携

`send-push` Edge Function を `valiark-prod` に向けるときは、次の secrets を設定する。

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`

手順の詳細は [docs/push_notification_prod_setup.md](../docs/push_notification_prod_setup.md) を参照。

このリポジトリでは、次のスクリプトでも同じ設定を入れられる。

```bash
SUPABASE_PROJECT_REF=<prod-project-ref> \
SUPABASE_URL=https://<prod-project>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<service_role> \
FCM_PROJECT_ID=<firebase-project-id> \
FCM_SERVICE_ACCOUNT_JSON='<service-account-json>' \
scripts/set_supabase_prod_push_secrets.sh
```

注意:

- 既に SQL Editor だけで同じDDLを流している場合、CLI の履歴とDB実体がズレることがある。そのときは [migration repair](https://supabase.com/docs/reference/cli/supabase-migration-repair) などで方針を決める。
- 初回 `0001_init.sql` は **空のDB** に向けるのが安全。既存テーブルがあるプロジェクトでは衝突するので、別ブランチ用プロジェクトかバックアップ後に実行する。
