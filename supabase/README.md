## Supabase migrations

このフォルダは Supabase のDBスキーマ（DDL / index / RLS）を管理する。

- 正本: `doc/db-table-design-final-mvp.md`
- 初版: `supabase/migrations/0001_init.sql`

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
   cd "/Users/makiyuto/dev/Who eats"
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

注意:

- 既に SQL Editor だけで同じDDLを流している場合、CLI の履歴とDB実体がズレることがある。そのときは [migration repair](https://supabase.com/docs/reference/cli/supabase-migration-repair) などで方針を決める。
- 初回 `0001_init.sql` は **空のDB** に向けるのが安全。既存テーブルがあるプロジェクトでは衝突するので、別ブランチ用プロジェクトかバックアップ後に実行する。

