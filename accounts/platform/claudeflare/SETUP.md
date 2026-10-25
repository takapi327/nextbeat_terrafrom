# Cloudflare OS サンプル実装 — 構築手順

設計は [README.md](./README.md) を参照。手順は「無料でできる確認 → 課金が発生する構築」の順に並べている。
各ステップは独立して戻せるので、途中でやめても削除手順（ステップ 8）だけ実施すればよい。

## 前提ツール

```console
$ brew install tfenv pnpm cloudflared gh
$ tfenv install 1.4.6   # ルートの .terraform-version に合わせる
$ npm install -g wrangler
```

アカウント類:

- Cloudflare アカウント（検証用ドメインを 1 つ zone 登録しておく。Workers Paid $5/月 に加入）
- Azure AD（Entra ID）テナントの管理権限（アプリ登録ができること）
- AWS platform アカウント（既存）

## ステップ 1: ローカル実行で機能確認（0円）

デプロイ前に、Cloudflare OS 自体の挙動（チャット / Gadget / 共有）をローカルで確認する。

```console
$ gh repo clone takapi327/cloudflare-os   # フォーク作成は FORK.md 参照
$ cd cloudflare-os
$ pnpm run-local
# → http://localhost:8787
```

- データは `.wrangler/` 配下に保存される（使い捨て可）
- ローカルの workerd は自分のマシンの経路で外に出るため、VPN で届く先の MCP なら
  この時点で `MCP_ALLOW_INSECURE=true` を併用して接続検証できる（ローカル開発専用スイッチ）

## ステップ 2: Cloudflare API トークンの作成

Cloudflare ダッシュボード → My Profile → API Tokens で、以下の権限を持つトークンを作成する。

| スコープ | 権限 |
|---|---|
| Zone / 対象 zone | DNS: Edit, Zone WAF: Edit |
| Account | Cloudflare Tunnel: Edit, Access: Apps and Policies: Edit, Access: Organizations: Edit |

作成したトークンは Terraform Cloud の workspace `platform-claudeflare` に
環境変数 `CLOUDFLARE_API_TOKEN`（sensitive）として登録する。リポジトリには置かない。

## ステップ 3: Entra ID 側のアプリ登録

1. Azure Portal → Microsoft Entra ID → アプリの登録 → 新規登録（名前例: `cloudflare-access-poc`）
2. リダイレクト URI: `https://<チーム名>.cloudflareaccess.com/cdn-cgi/access/callback`
   - チーム名は Cloudflare Zero Trust ダッシュボードの初回セットアップで決める
3. 「証明書とシークレット」でクライアントシークレットを発行
4. API のアクセス許可: `Microsoft Graph > User.Read`, `Group.Read.All`（グループ認可を使うため）に管理者同意
5. 検証用グループ（例: `cloudflare-os-poc-users`）を作り、自分を追加

控える値: ディレクトリ (テナント) ID / アプリケーション (クライアント) ID / クライアントシークレット。
Terraform Cloud に `entra_tenant_id` / `entra_client_id` / `entra_client_secret`（sensitive）として登録する。

## ステップ 4: Terraform でインフラ構築

このディレクトリに README.md 3.4 節のファイル構成で実装する（スキーマは terraform-registry で要確認）。
最低限の骨子は以下。

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.4.6"

  cloud {
    organization = "takapi327"
    workspaces { name = "platform-claudeflare" }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }
}
```

```hcl
# access.tf — Entra を IdP にし、対象グループのみ許可する
resource "cloudflare_zero_trust_access_identity_provider" "entra" {
  account_id = var.cloudflare_account_id
  name       = "Entra ID"
  type       = "azureAD"
  config = {
    client_id     = var.entra_client_id
    client_secret = var.entra_client_secret
    directory_id  = var.entra_tenant_id
    support_groups = true
  }
}

resource "cloudflare_zero_trust_access_application" "cloudflare_os" {
  zone_id = var.zone_id
  name    = "cloudflare-os-poc"
  domain  = "os.${var.domain}"
}

resource "cloudflare_zero_trust_access_policy" "cloudflare_os_users" {
  application_id = cloudflare_zero_trust_access_application.cloudflare_os.id
  zone_id        = var.zone_id
  name           = "poc-users"
  decision       = "allow"
  include = [{ azure_ad = { id = var.entra_poc_group_id, identity_provider_id = cloudflare_zero_trust_access_identity_provider.entra.id } }]
}
```

```hcl
# tunnel.tf — AWS 側からの外向き接続のみで MCP を公開する
resource "cloudflare_zero_trust_tunnel_cloudflared" "poc" {
  account_id = var.cloudflare_account_id
  name       = "claudeflare-poc"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "poc" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.poc.id
  config = {
    ingress = [
      { hostname = "mcp.${var.domain}", service = "http://localhost:3000" }, # サンプル MCP
      { service = "http_status:404" },                                       # 既定は拒否
    ]
  }
}
```

適用:

```console
$ cd accounts/platform/claudeflare
$ terraform init
$ terraform plan    # 差分が設計どおりか確認してから
$ terraform apply
```

## ステップ 5: AWS 側 — cloudflared とサンプル MCP の起動

PoC では EC2（t4g.nano）1 台に docker compose で同居させるのが最小構成。
SG は **inbound 全拒否・outbound 443 のみ許可**にする（Tunnel は外向き接続だけで成立することの確認を兼ねる）。

```yaml
# /opt/poc/compose.yaml（イメージは実装時に選定）
services:
  mcp-sample:
    image: <サンプル MCP サーバーのイメージ>   # 例: 社内 API を数ツールだけ生やした最小実装
    ports: ["3000:3000"]
  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel run --token ${TUNNEL_TOKEN}   # token は terraform output から取得（sensitive）
    network_mode: "service:mcp-sample"
```

起動後、Cloudflare ダッシュボードの Tunnel が `HEALTHY` になることを確認する。

## ステップ 6: Cloudflare OS のデプロイ

フォーク（[FORK.md](./FORK.md)）から wrangler でデプロイし、独自ドメインと Access 検証を設定する。

1. `os.<ドメイン>` を Workers のカスタムドメインに割り当て、`workers.dev` ルートは無効化する
2. Access の AUD / Issuer を Workers の環境変数に設定（`CF_ACCESS_AUD` / `CF_ACCESS_ISS`）
   — Cloudflare OS 本体が `cf-access-jwt-assertion` を検証する実装を持っているため、これだけで Access 連携になる
3. `gatekeeper-mcp` を有効化し、UI から `https://mcp.<ドメイン>` を MCP エンドポイントとして接続

簡易に済ませたい場合は公式デプロイフロー `https://os.cloudflare.app/deploy` も使えるが、
フォークの検証という目的上、wrangler 直デプロイを基本とする。

## ステップ 7: 動作確認

README.md の「4. 検証項目」のチェックリストを上から順に実施する。
特に以下の 2 点は本番提案の根拠になるため、スクリーンショットを残す。

- AWS 側 SG が inbound 全拒否のまま MCP ツール呼び出しが成功すること
- 共有した Gadget が、MCP 権限のないユーザーには開けないこと（observer 検証）

## ステップ 8: 片付け

```console
$ terraform destroy            # Cloudflare / AWS リソースの削除
$ wrangler delete              # Workers の削除（フォーク側リポジトリで実行）
```

Entra のアプリ登録とクライアントシークレット、Terraform Cloud の sensitive variables も忘れずに削除する。
