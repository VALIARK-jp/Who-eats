# valiark-prod: Who eats prod 接続・ビルド手順

**目的:** `valiark-prod` に Who eats の DB / Edge Functions / release build を揃え、prod 相当の挙動をローカルでも再現できるようにする。  
**正本:** この文書と `scripts/valiark-prod-supabase-setup.sh` / `scripts/flutter_run_prod.sh` / `scripts/flutter_build_prod.sh`

---

## 1. 準備

1. [`scripts/valiark-project-refs.env.example`](../scripts/valiark-project-refs.env.example) を `scripts/valiark-project-refs.env` にコピーする。
2. `VALIARK_PROD_PROJECT_REF` に `valiark-prod` の Reference ID を入れる。
3. [`.env.prod.example`](../.env.prod.example) を `.env.prod` にコピーして値を埋める。
4. 必要なら `supabase login` を済ませる。

---

## 2. Supabase DB

prod プロジェクトが空なら、migration をそのまま `db push` する。

```bash
./scripts/valiark-prod-supabase-setup.sh db
```

手動でやる場合:

```bash
supabase login
supabase link --project-ref "$VALIARK_PROD_PROJECT_REF"
supabase db push
```

### 接続が失敗するとき

- Supabase Dashboard の Network Bans / Network Restrictions を確認する
- `SUPABASE_DB_PASSWORD` を使う
- `SUPABASE_DB_URL` に Session pooler の URI を直接入れる
- それでもだめなら `supabase/migrations/` を SQL Editor で順番に流す

---

## 3. Edge Functions

Who eats の prod では次を想定する。

- `send-push`

デプロイ:

```bash
./scripts/valiark-prod-supabase-setup.sh functions
```

`send-push` を使う場合は、[`docs/push_notification_prod_setup.md`](./push_notification_prod_setup.md) の FCM secret 設定も必要。

---

## 4. Prod run / build

`flutter_dotenv` と iOS / Android のネイティブ設定が一致するよう、prod コマンドは `.env.prod` を一時的に `.env` に差し替えて実行する。

### ローカルで prod を再現

```bash
./scripts/flutter_run_prod.sh
```

### release build

```bash
./scripts/flutter_build_prod.sh
```

---

## 5. 使い分け

| 目的 | コマンド |
|------|----------|
| DB を prod に載せる | `./scripts/valiark-prod-supabase-setup.sh db` |
| Edge Functions を prod に載せる | `./scripts/valiark-prod-supabase-setup.sh functions` |
| prod 相当でローカル確認 | `./scripts/flutter_run_prod.sh` |
| release build | `./scripts/flutter_build_prod.sh` |
