# Cloudflare OS サンプル実装 — 設計

Cloudflare OS（AI エージェントワークスペース）の PoC 環境を個人検証用に構築するための設計ドキュメント。
本番提案（会社リポジトリ `plan/2026-10-25-cloudflare-os-proposal.md`）のミニチュア版として、
以下を最小コストで検証することを目的とする。

1. Azure AD（Entra ID）による認証認可（Cloudflare Access 経由）
2. AWS 上の MCP サーバーへの Cloudflare Tunnel 経由のセキュア接続
3. Cloudflare OS 本体（フォーク版）の Workers へのデプロイ
4. Gadget 作成・限定共有・監査ログの挙動確認

関連ドキュメント:

- 構築手順: [SETUP.md](./SETUP.md)
- cloudflare-os フォーク手順: [FORK.md](./FORK.md)

## 1. 全体構成

```
社員(検証ユーザー)
   │ HTTPS
   ▼
Cloudflare エッジ
   ├─ WAF カスタムルール: os.<ドメイン> 宛てのうち自宅/社内 IP 以外を遮断
   ├─ Cloudflare Access (os.<ドメイン>): Azure AD (Entra ID) 認証 + グループ認可  ← 無料50席
   ▼
Cloudflare Workers
   └─ Cloudflare OS (フォーク版)
        ├─ router / workshop-frontend / workshop-backend (Durable Object)
        ├─ Gadget サンドボックス (Dynamic Worker)
        └─ gatekeeper-mcp ─────────┐ CF-Access-Client-Id / Secret ヘッダー付きで呼び出し
                                    ▼
                         Cloudflare Access (mcp.<ドメイン>): サービストークンのみ許可
                                    │ Cloudflare Tunnel (AWS から外向き接続のみ, 7844/tcp+udp)
AWS platform アカウント             │
   └─ VPC (既存 platform VPC を流用)◄┘
        ├─ IGW + public ルートテーブル（本 workspace で追加、3.1.1 参照）
        └─ sn-global-1 上の EC2 (t4g.nano, パブリック IP あり / inbound 全拒否)
             ├─ cloudflared コネクタ
             └─ サンプル MCP サーバー
```

- LLM は AI Gateway 経由で Workers AI（無料枠）を使用。品質検証時のみ Bedrock に切替
- 想定ランニングコスト: Workers Paid $5/月 + cloudflared 用 EC2(t4g.nano) 数ドル + LLM 従量数ドル
  （NAT Gateway は月 $40 以上かかるため使わない。3.1.1 参照）

## 2. リポジトリと責務の境界

| リポジトリ | 管理対象 | デプロイ手段 |
|---|---|---|
| `takapi327/nextbeat_terrafrom`（本リポジトリ） | Cloudflare リソース（Access / WAF / Tunnel / DNS）+ AWS リソース（IGW・ルート、cloudflared、サンプル MCP） | Terraform Cloud |
| `takapi327/cloudflare-os`（フォーク、[FORK.md](./FORK.md) 参照） | Cloudflare OS 本体 + 独自ゲートキーパー | wrangler（手元から） |

シークレット（Cloudflare API トークン、Entra クライアントシークレット、Tunnel トークン、Access サービストークン）は
Terraform Cloud の sensitive variable / sensitive output と wrangler secrets に置き、リポジトリにはコミットしない。

## 3. Terraform 設計

### 3.1 ワークスペース

既存規約（`platform-vpclattice` 等）に合わせる。

- Terraform Cloud organization: `takapi327`
- workspace: `platform-claudeflare`
- 既存 `platform` workspace の VPC / サブネットを `terraform_remote_state` で参照
  （`vpc_id`、`sn_global_1_id` は既に output されている）

#### 3.1.1 インターネットへの出口（要対応）

既存 platform VPC には **IGW も NAT もない**（`rtb-private` にデフォルトルートなし、global サブネットはメインルートテーブルのまま）。
このままでは cloudflared が Cloudflare エッジへ接続できず、Docker イメージの pull もできない。

| 案 | 内容 | 評価 |
|---|---|---|
| **A. 本 workspace で IGW + public ルートを追加（採用）** | `aws_internet_gateway` を platform VPC に attach し、0.0.0.0/0 → IGW のルートテーブルを `sn-global-1` に関連付ける。EC2 は `associate_public_ip_address = true` | 月額 0 円。`terraform destroy` で PoC ごと消せる |
| B. platform workspace 側に IGW / public ルートを追加 | `productA/gateway.tf` + `route.tf` と同じ形を platform に入れる | 恒久的な変更になる。他用途でも IGW が必要になったらこちらへ移す |
| C. NAT Gateway | private サブネットに置き、NAT 経由で外に出す | 月 $40 以上かかり PoC の想定コストを超える |

注意:

- IGW は 1 VPC に 1 つしか attach できない。将来 platform workspace でも IGW を作る場合は、先に本 workspace から外す（または `terraform state` で移す）こと
- `sn-global-1` は既存リソースが使っていないことを apply 前に確認する（現状、platform workspace 内でルートテーブルの関連付けはない）

#### 3.1.2 実行モード（要確認）

認証情報をどこに置くかは、workspace の Execution Mode によって変わる。

| Execution Mode | AWS 認証情報 | Cloudflare / Entra のシークレット・tfvars |
|---|---|---|
| Remote | TFC workspace の env variable（`AWS_ACCESS_KEY_ID` 等。SSO の一時認証情報は 1 時間で切れるので、更新するか OIDC 連携を使う） | TFC workspace の variable（sensitive） |
| Local | 手元のターミナルに SSO の環境変数をペースト（既存手順） | 手元の環境変数（`CLOUDFLARE_API_TOKEN`、`TF_VAR_*`）。**TFC の variable は使われない** |

既存 workspace のモードを TFC の画面で確認し、`platform-claudeflare` も同じモードに揃える。
本ドキュメントでは「TFC variable に登録」と書いている箇所があるが、Local の場合は手元の環境変数に読み替える。

### 3.2 プロバイダ

| プロバイダ | 用途 | 認証 |
|---|---|---|
| `cloudflare/cloudflare`（v5 系） | zone 設定 / Access / Tunnel / WAF / DNS | `CLOUDFLARE_API_TOKEN`（置き場所は 3.1.2 参照） |
| `hashicorp/aws`（4.67.0） | IGW・ルート / cloudflared / サンプル MCP / SG | 既存と同じ |

実装時は provider スキーマを terraform-registry（MCP）で必ず確認すること。
v5 で特に間違えやすい点:

- Zero Trust 系リソースは v4 → v5 で `cloudflare_access_*` から `cloudflare_zero_trust_access_*` に改名されている
- `cloudflare_zero_trust_access_policy` は **account 単位の再利用可能ポリシー**。`account_id` が必須で、`application_id` / `zone_id` は持たない。
  アプリへの紐付けはアプリ側の `policies = [{ id = ..., precedence = N }]` で行う
- `cloudflare_zero_trust_tunnel_cloudflared` は Tunnel トークンを属性として返さない。
  トークンはデータソース `cloudflare_zero_trust_tunnel_cloudflared_token`（`account_id` + `tunnel_id`）で取得する
- Terraform 1.4.6 で cloudflare v5 の `terraform init` / `plan` が通るか最初に確認する（通らなければ本 workspace だけ Terraform を上げる）

### 3.3 管理リソース一覧

| 分類 | リソース（v5 系の名称） | 備考 |
|---|---|---|
| 入口制御 | `cloudflare_ruleset`（phase: `http_request_firewall_custom`） | **`os.<ドメイン>` 宛てに限定して**許可 IP 以外を block。ゾーン全体にかけると Workers から `mcp.` への呼び出し（送信元は自宅 IP ではない）まで遮断される |
| 認証 IdP | `cloudflare_zero_trust_access_identity_provider`（type: `azureAD`） | Entra アプリのクライアント ID / シークレットを設定 |
| 認可（OS） | `cloudflare_zero_trust_access_application`（`os.`）+ `cloudflare_zero_trust_access_policy`（decision: `allow`） | include = Entra グループ |
| 認可（MCP） | `cloudflare_zero_trust_access_application`（`mcp.`）+ `cloudflare_zero_trust_access_policy`（decision: `non_identity`）+ `cloudflare_zero_trust_access_service_token` | include = サービストークン。これがないと `mcp.` のホスト名を知っている人は誰でも MCP ツールを呼べる |
| Tunnel | `cloudflare_zero_trust_tunnel_cloudflared` + `_config`、データソース `_token` | ingress: サンプル MCP のコンテナへ |
| DNS | `cloudflare_dns_record` | `os.<検証ドメイン>`（Workers へ）と `mcp.<検証ドメイン>`（Tunnel へ、CNAME `<tunnel-id>.cfargotunnel.com`、proxied） |
| AWS ネットワーク | `aws_internet_gateway` + `aws_route_table` + `aws_route_table_association` | 3.1.1 案 A |
| AWS 実行環境 | `aws_instance`（t4g.nano, arm64）or ECS サービス ×2 | cloudflared / サンプル MCP。sn-global-1 に配置しパブリック IP を付与 |
| AWS SG | `aws_security_group` | inbound なし。egress は 7844/tcp・7844/udp（Tunnel）と 443/tcp（イメージ pull・OS 更新・cloudflared の API 通信） |

### 3.4 ファイル構成（実装時）

```
accounts/platform/claudeflare/
├── README.md            # 本ドキュメント（設計）
├── SETUP.md             # 構築手順
├── FORK.md              # cloudflare-os フォーク手順
├── terraform.tf         # TF Cloud backend（workspace: platform-claudeflare）+ remote_state
├── provider.tf          # cloudflare / aws プロバイダ
├── variables.tf         # cloudflare_account_id, zone_id, domain, allowed_ips, entra_* (sensitive) 等
├── access.tf            # IdP / Access application ×2 / policy ×2 / service token
├── waf.tf               # IP 許可リスト ruleset（os. 限定）
├── tunnel.tf            # Tunnel 本体 + ingress 設定 + token データソース
├── dns.tf               # os / mcp レコード
├── network.tf           # IGW + public ルートテーブル（3.1.1 案 A）
├── ec2.tf               # cloudflared + サンプル MCP ホスト
├── security.tf          # SG（inbound なし、egress 7844/443）
└── outputs.tf           # tunnel token・サービストークン（sensitive）、各ホスト名
```

## 4. 検証項目（Done の定義）

- [ ] 許可 IP 以外から `os.<ドメイン>` にアクセスできない（WAF が先に遮断）
- [ ] 許可 IP からのアクセスで Entra ログイン画面に飛び、対象グループのユーザーのみ通過できる
- [ ] Cloudflare OS 上でチャット・Gadget 作成ができ、成果物が永続する
- [ ] `gatekeeper-mcp` から Tunnel 経由でサンプル MCP のツールを呼び出せる（AWS 側 inbound 許可ゼロのまま）
- [ ] サービストークンのヘッダーなしで `https://mcp.<ドメイン>` を直接呼ぶと Access に拒否される
- [ ] Gadget を別ユーザーに `use` ロールで共有でき、observer 検証が効く
- [ ] Gatekeeper のアクションジャーナルに MCP 呼び出しが記録されている

## 5. 本番（会社）構成との差分

| 項目 | 本サンプル | 本番提案 |
|---|---|---|
| Access 席数 | 無料枠（50席以内） | 300席（有償） |
| MCP 認可 | `gatekeeper-mcp`（エンドポイント直指定）+ `mcp.` を Access サービストークンで保護 | MCP Server Portal（Access ポリシーで認可） |
| LLM | Workers AI 無料枠 | Bedrock（AWS 請求） |
| ログ長期保存 | なし（ダッシュボード確認のみ） | Logpush → S3 + Access ログ pull |
| cloudflared | EC2 1台（public サブネット + IGW） | Fargate 冗長化（private サブネット + NAT / VPC エンドポイント） |
