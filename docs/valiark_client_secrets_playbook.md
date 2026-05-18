# Valiark クライアント秘密・オンボーディング運用ガイド

**目的:** Panda Talk、Who eats、その他 Valiark のクライアント（主にモバイル）で **「何を誰に渡すか」「リポジトリに何を書いてよいか」** を揃え、オンボーディングとインシデントを減らす。  
**位置づけ:** 各リポジトリの実装（`flutter_dotenv` の有無、dart-define 専用か、など）は **アプリごとに異なってよい**。この文書は **ルールと分類** を共有するためのものである。

他アプリの UI やディレクトリ構成をそのまま踏襲する必要はない。認証画面のボタン配置など **見た目の参考** と、ここに書く **秘密の扱い** は切り離して考える。

---

## 1. 秘密の分類（共通言語）

| 区分 | 例 | クライアントに渡す | Git にコミット |
|------|-----|-------------------|----------------|
| **公開してよいクライアント用** | Supabase **anon** key、公開 API の base URL、LINE **チャンネル ID**（Login 用）、アプリの redirect URL（スキーム含む）、Google Maps **クライアント用**キー（制限付き） | メール / 1Password / オンボーディング手順で **可** | **原則不可**（`.env.example` には **チーム固有の秘密を書かない**） |
| **サーバー・CI のみ** | Supabase **service_role**、LINE **チャンネルシークレット**、Webhook の署名秘密、決済の秘密鍵 | **クライアント開発者に渡さない** | **絶対不可** |
| **個人・端末ローカル** | 上記「公開してよい」値のコピーを開発者が **`.env`**（gitignore）に置く | 各自のマシンのみ | `.gitignore` で除外 |

**anon と service_role:** anon は Row Level Security の前提で「クライアントに埋め込まれる」設計だが、**リポジトリの履歴に残さない**運用を推奨する。service_role は RLS をバイパスするため **Flutter・モバイル・フロントのビルド引数・`.env` に一切入れない**。

---

## 2. ジョイン時にメール等で渡してよいもの（チェックリスト）

オンボーディング担当が新メンバーに渡す想定:

- [ ] 開発用 Supabase プロジェクトの **URL**
- [ ] 同プロジェクトの **anon** key（本番用は別チケット・別 vault で）
- [ ] LINE Login 用 **チャンネル ID**（アプリと Supabase Edge Function の設定と一致させる）
- [ ] バックエンドの **開発用 base URL**（例: ローカル Cloudflare Worker）
- [ ] 認証リダイレクトに使う **許可済み URL**（例: `io.valiark.auth://callback`）と、ダッシュボードで許可する手順へのリンク

**渡さない:** service_role、LINE channel secret、本番のみの鍵、他社・他プロジェクトの秘密。

---

## 3. リポジトリに書いてよいもの

- **キー名の列挙**（`README` や `.env*.example`）: 可
- **anon の実値をソースの `defaultValue` に置く習慣:** 避ける。移行時は env / dart-define に寄せ、デフォルトは空にする。

---

## 4. ローカル開発での置き方（このリポジトリ）

- **`flutter_dotenv` + ルートの `.env`**（テンプレは [`.env.example`](../.env.example)）。`pubspec.yaml` の assets に `.env` が含まれるため、**初回は `cp .env.example .env` が必須**。
- **`--dart-define`:** `AppConfig` は **dart-define を `.env` より優先**（Panda Talk と同じ）。CI や一時的な上書きに使う。

---

## 5. CI / 本番ビルド

- **service_role** や LINE **secret** は CI の **encrypted secrets** や Supabase の **Function secrets** にのみ置く。
- クライアント向けビルドでは **anon** まで。ビルドログに秘密が出ないようマスクする。

---

## 6. 他リポジトリへの展開

- Who eats、Panda Talk など **同じ内容のファイルをコピー**してもよい。あるいは社内 Notion / Drive に **単一の正本** を置き、各 README からリンクする。
- アプリ固有のプレフィックス（例: `WHOEATS_*`）はそのままでよい。**分類ルール（この文書の表）** を共有することが主目的。

---

## 7. 関連ドキュメント（このリポジトリ）

- プロジェクト概要・Maps API: [README.md](../README.md)
- Google Maps セットアップ: [doc/google-maps-api-checklist.md](../doc/google-maps-api-checklist.md)
