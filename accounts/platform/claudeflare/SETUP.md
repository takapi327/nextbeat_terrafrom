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

### 事前確認: Terraform Cloud の実行モード

ステップ 2・3 で作るシークレットをどこに置くかは、workspace の Execution Mode で変わる（README.md 3.1.2）。
既存 workspace（`platform` 等）のモードを TFC の画面で確認し、`platform-claudeflare` も同じモードで作成しておく。

- **Remote**: 以降の「TFC に登録」をそのまま実施する。AWS 認証情報も TFC の env variable に置く
- **Local**: 以降の「TFC に登録」は、手元の環境変数（`CLOUDFLARE_API_TOKEN`、`TF_VAR_entra_client_secret` 等）に読み替える

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
| Account | Cloudflare Tunnel: Edit, Access: Apps and Policies: Edit, Access: Organizations: Edit, Access: Service Tokens: Edit |

作成したトークンは Terraform Cloud の workspace `platform-claudeflare` に
環境変数 `CLOUDFLARE_API_TOKEN`（sensitive）として登録する。リポジトリには置かない。

## ステップ 3: Entra ID 側のアプリ登録

1. Azure Portal → Microsoft Entra ID → アプリの登録 → 新規登録（名前例: `cloudflare-access-poc`）
2. リダイレクト URI: `https://<チーム名>.cloudflareaccess.com/cdn-cgi/access/callback`
   - チーム名は Cloudflare Zero Trust ダッシュボードの初回セットアップで決める
3. 「証明書とシークレット」でクライアントシークレットを発行
4. API のアクセス許可: `Microsoft Graph > User.Read`, `Group.Read.All`（グループ認可を使うため）に管理者同意
5. 検証用グループ（例: `cloudflare-os-poc-users`）を作り、自分を追加

控える値と、Terraform Cloud に登録する変数名:

| 値 | 変数名 | sensitive |
|---|---|---|
| ディレクトリ (テナント) ID | `entra_tenant_id` | |
| アプリケーション (クライアント) ID | `entra_client_id` | |
| クライアントシークレット | `entra_client_secret` | ✓ |
| 検証用グループのオブジェクト ID | `entra_poc_group_id` | |

Cloudflare 側の値も合わせて登録する: `cloudflare_account_id`、`zone_id`、`domain`（検証ドメイン）、`allowed_ips`（自宅/社内 IP のリスト）。

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

data "terraform_remote_state" "platform" {
  backend = "remote"

  config = {
    organization = "takapi327"

    workspaces = {
      name = "platform"
    }
  }
}
```

最初に `terraform init` だけ実行し、Terraform 1.4.6 で cloudflare v5 プロバイダを取得・初期化できることを確認する。
失敗する場合は本 workspace だけ `.terraform-version` を置いて Terraform を上げる。

```hcl
# network.tf — 既存 platform VPC には IGW がないため、本 workspace で出口を用意する（README.md 3.1.1 案 A）
resource "aws_internet_gateway" "claudeflare" {
  vpc_id = data.terraform_remote_state.platform.outputs.vpc_id

  tags = {
    Name : "igw-platform-claudeflare"
  }
}

resource "aws_route_table" "rtb_public" {
  vpc_id = data.terraform_remote_state.platform.outputs.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.claudeflare.id
  }

  tags = {
    Name : "rtb-public-claudeflare"
  }
}

resource "aws_route_table_association" "global_1" {
  route_table_id = aws_route_table.rtb_public.id
  subnet_id      = data.terraform_remote_state.platform.outputs.sn_global_1_id
}
```

```hcl
# security.tf — inbound は 1 つも作らない
resource "aws_security_group" "cloudflared" {
  name        = "claudeflare-cloudflared"
  description = "cloudflared and sample MCP (egress only)"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id
}

resource "aws_security_group_rule" "tunnel_tcp" {
  security_group_id = aws_security_group.cloudflared.id
  type              = "egress"
  from_port         = 7844
  to_port           = 7844
  protocol          = "tcp"   # http2
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "tunnel_udp" {
  security_group_id = aws_security_group.cloudflared.id
  type              = "egress"
  from_port         = 7844
  to_port           = 7844
  protocol          = "udp"   # quic
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.cloudflared.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"   # イメージ pull・OS 更新・cloudflared の API 通信
  cidr_blocks       = ["0.0.0.0/0"]
}
```

```hcl
# access.tf — Entra を IdP にし、os. は対象グループのみ、mcp. はサービストークンのみ許可する
resource "cloudflare_zero_trust_access_identity_provider" "entra" {
  account_id = var.cloudflare_account_id
  name       = "Entra ID"
  type       = "azureAD"
  config = {
    client_id      = var.entra_client_id
    client_secret  = var.entra_client_secret
    directory_id   = var.entra_tenant_id
    support_groups = true
  }
}

# v5 のポリシーは account 単位。アプリへの紐付けはアプリ側の policies で行う
resource "cloudflare_zero_trust_access_policy" "cloudflare_os_users" {
  account_id = var.cloudflare_account_id
  name       = "poc-users"
  decision   = "allow"
  include = [{
    azure_ad = {
      id                   = var.entra_poc_group_id
      identity_provider_id = cloudflare_zero_trust_access_identity_provider.entra.id
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "cloudflare_os" {
  zone_id = var.zone_id
  name    = "cloudflare-os-poc"
  type    = "self_hosted"
  domain  = "os.${var.domain}"
  policies = [{
    id         = cloudflare_zero_trust_access_policy.cloudflare_os_users.id
    precedence = 1
  }]
}

# mcp. は Tunnel で公開されるため、Access をかけないとホスト名を知っている人が誰でも MCP を呼べる
resource "cloudflare_zero_trust_access_service_token" "gatekeeper_mcp" {
  account_id = var.cloudflare_account_id
  name       = "gatekeeper-mcp"
}

resource "cloudflare_zero_trust_access_policy" "gatekeeper_mcp" {
  account_id = var.cloudflare_account_id
  name       = "gatekeeper-mcp-service-token"
  decision   = "non_identity"
  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.gatekeeper_mcp.id
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "mcp" {
  zone_id = var.zone_id
  name    = "mcp-sample-poc"
  type    = "self_hosted"
  domain  = "mcp.${var.domain}"
  policies = [{
    id         = cloudflare_zero_trust_access_policy.gatekeeper_mcp.id
    precedence = 1
  }]
}
```

```hcl
# waf.tf — os. 宛てに限定して IP 制限する。
# ゾーン全体にかけると、Workers（送信元は自宅 IP ではない）から mcp. への呼び出しまで遮断される
resource "cloudflare_ruleset" "ip_allowlist" {
  zone_id = var.zone_id
  name    = "poc-ip-allowlist"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules = [{
    action      = "block"
    description = "Block os. except allowed IPs"
    enabled     = true
    expression  = "(http.host eq \"os.${var.domain}\" and not ip.src in {${join(" ", var.allowed_ips)}})"
  }]
}
```

```hcl
# tunnel.tf — AWS 側からの外向き接続のみで MCP を公開する
resource "cloudflare_zero_trust_tunnel_cloudflared" "poc" {
  account_id = var.cloudflare_account_id
  name       = "claudeflare-poc"
  config_src = "cloudflare"
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

# v5 のリソースは Tunnel トークンを返さないので、データソースで取得する
data "cloudflare_zero_trust_tunnel_cloudflared_token" "poc" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.poc.id
}
```

```hcl
# outputs.tf
output "tunnel_token" {
  value     = data.cloudflare_zero_trust_tunnel_cloudflared_token.poc.token
  sensitive = true
}

output "gatekeeper_mcp_client_id" {
  value = cloudflare_zero_trust_access_service_token.gatekeeper_mcp.client_id
}

output "gatekeeper_mcp_client_secret" {
  value     = cloudflare_zero_trust_access_service_token.gatekeeper_mcp.client_secret
  sensitive = true
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

- 配置先は `sn-global-1`（ステップ 4 の `network.tf` で IGW 向けルートを関連付けたサブネット）にし、
  `associate_public_ip_address = true` を付ける。パブリック IP がないと IGW 経由で外に出られない
- SG はステップ 4 の `aws_security_group.cloudflared`（**inbound 全拒否・outbound は 7844/tcp・7844/udp・443/tcp のみ**）を使う。
  Tunnel は 443 ではなく 7844 で張られるので、443 だけでは `HEALTHY` にならない
- t4g は arm64 なので、AMI は arm64 版を選び、サンプル MCP のイメージも arm64（またはマルチアーキ）でビルドする
  （cloudflared の公式イメージは arm64 対応済み）

```yaml
# /opt/poc/compose.yaml（イメージは実装時に選定）
services:
  mcp-sample:
    image: <サンプル MCP サーバーのイメージ>   # 例: 社内 API を数ツールだけ生やした最小実装。arm64 対応必須
    ports: ["3000:3000"]
  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel run --token ${TUNNEL_TOKEN}   # terraform output -raw tunnel_token で取得（sensitive）
    network_mode: "service:mcp-sample"
```

起動後、Cloudflare ダッシュボードの Tunnel が `HEALTHY` になることを確認する。

## ステップ 6: Cloudflare OS のデプロイ

フォーク（[FORK.md](./FORK.md)）から wrangler でデプロイし、独自ドメインと Access 検証を設定する。

1. `os.<ドメイン>` を Workers のカスタムドメインに割り当て、`workers.dev` ルートは無効化する
2. Access の AUD / Issuer を Workers の環境変数に設定（`CF_ACCESS_AUD` / `CF_ACCESS_ISS`）
   — Cloudflare OS 本体が `cf-access-jwt-assertion` を検証する実装を持っているため、これだけで Access 連携になる
3. `gatekeeper-mcp` を有効化し、UI から `https://mcp.<ドメイン>` を MCP エンドポイントとして接続する。
   `mcp.` には Access がかかっているため、リクエストに次のヘッダーを付ける必要がある
   - `CF-Access-Client-Id`: `terraform output gatekeeper_mcp_client_id`
   - `CF-Access-Client-Secret`: `terraform output -raw gatekeeper_mcp_client_secret`（`wrangler secret put` で設定する）
   - `gatekeeper-mcp` が接続先ごとにカスタムヘッダーを設定できるかは要確認。できない場合は、ヘッダーを付ける
     独自ゲートキーパーを `packages/gatekeeper-<name>/` に追加する（FORK.md 3 節の置き場所ルールに従う）

簡易に済ませたい場合は公式デプロイフロー `https://os.cloudflare.app/deploy` も使えるが、
フォークの検証という目的上、wrangler 直デプロイを基本とする。

## ステップ 7: 動作確認

README.md の「4. 検証項目」のチェックリストを上から順に実施する。
特に以下の 3 点は本番提案の根拠になるため、スクリーンショットを残す。

- AWS 側 SG が inbound 全拒否のまま MCP ツール呼び出しが成功すること
- サービストークンなしで `https://mcp.<ドメイン>` を直接叩くと Access に拒否されること
  （例: `curl -i https://mcp.<ドメイン>` が Access のログイン画面へのリダイレクトまたは 403 になる）
- 共有した Gadget が、MCP 権限のないユーザーには開けないこと（observer 検証）

## ステップ 8: 片付け

```console
$ terraform destroy            # Cloudflare / AWS リソースの削除（IGW・public ルートテーブルも消える）
$ wrangler delete              # Workers の削除（フォーク側リポジトリで実行）
```

Entra のアプリ登録とクライアントシークレット、Terraform Cloud の sensitive variables も忘れずに削除する。
