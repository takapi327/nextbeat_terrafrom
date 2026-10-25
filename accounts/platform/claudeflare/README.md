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
   ├─ WAF カスタムルール: 自宅/社内 IP 以外を遮断
   ├─ Cloudflare Access: Azure AD (Entra ID) 認証 + グループ認可  ← 無料50席
   ▼
Cloudflare Workers
   └─ Cloudflare OS (フォーク版)
        ├─ router / workshop-frontend / workshop-backend (Durable Object)
        ├─ Gadget サンドボックス (Dynamic Worker)
        └─ gatekeeper-mcp ─────────┐
                                    │ Cloudflare Tunnel (AWS から外向き接続のみ)
AWS platform アカウント             │
   └─ VPC (既存 platform VPC を流用)◄┘
        ├─ cloudflared コネクタ (EC2 1台 or ECS)
        └─ サンプル MCP サーバー (ECS or EC2 上のコンテナ)
```

- LLM は AI Gateway 経由で Workers AI（無料枠）を使用。品質検証時のみ Bedrock に切替
- 想定ランニングコスト: Workers Paid $5/月 + cloudflared 用 EC2(t4g.nano) 数ドル + LLM 従量数ドル

## 2. リポジトリと責務の境界

| リポジトリ | 管理対象 | デプロイ手段 |
|---|---|---|
| `takapi327/nextbeat_terrafrom`（本リポジトリ） | Cloudflare リソース（Access / WAF / Tunnel / DNS）+ AWS リソース（cloudflared、サンプル MCP） | Terraform Cloud |
| `takapi327/cloudflare-os`（フォーク、[FORK.md](./FORK.md) 参照） | Cloudflare OS 本体 + 独自ゲートキーパー | wrangler（手元から） |

シークレット（Cloudflare API トークン、Entra クライアントシークレット、Tunnel シークレット）は
Terraform Cloud の sensitive variable と wrangler secrets に置き、リポジトリにはコミットしない。

## 3. Terraform 設計

### 3.1 ワークスペース

既存規約（`platform-vpclattice` 等）に合わせる。

- Terraform Cloud organization: `takapi327`
- workspace: `platform-claudeflare`
- 既存 `platform` workspace の VPC / サブネットを `terraform_remote_state` で参照

### 3.2 プロバイダ

| プロバイダ | 用途 | 認証 |
|---|---|---|
| `cloudflare/cloudflare`（v5 系） | zone 設定 / Access / Tunnel / WAF / DNS | `CLOUDFLARE_API_TOKEN`（TF Cloud の env variable） |
| `hashicorp/aws` | cloudflared / サンプル MCP / SG | 既存と同じ |

実装時は provider スキーマを terraform-registry（MCP）で必ず確認すること。
Zero Trust 系リソースは v4 → v5 で `cloudflare_access_*` から `cloudflare_zero_trust_access_*` に改名されている。

### 3.3 管理リソース一覧

| 分類 | リソース（v5 系の名称） | 備考 |
|---|---|---|
| 入口制御 | `cloudflare_ruleset`（phase: `http_request_firewall_custom`） | 許可 IP リスト以外を block。検証中は自宅 IP |
| 認証 IdP | `cloudflare_zero_trust_access_identity_provider`（type: `azureAD`） | Entra アプリのクライアント ID / シークレットを設定 |
| 認可 | `cloudflare_zero_trust_access_application` + `cloudflare_zero_trust_access_policy` | Cloudflare OS のホスト名に適用。include = Entra グループ |
| Tunnel | `cloudflare_zero_trust_tunnel_cloudflared` + `_config` | ingress: サンプル MCP の内部 ALB / コンテナへ |
| DNS | `cloudflare_dns_record` | `os.<検証ドメイン>`（Workers へ）と `mcp.<検証ドメイン>`（Tunnel へ、CNAME `<tunnel-id>.cfargotunnel.com`） |
| AWS | `aws_instance`（t4g.nano）or ECS サービス ×2 | cloudflared / サンプル MCP。SG は egress のみ（inbound 許可なし） |

### 3.4 ファイル構成（実装時）

```
accounts/platform/claudeflare/
├── README.md            # 本ドキュメント（設計）
├── SETUP.md             # 構築手順
├── FORK.md              # cloudflare-os フォーク手順
├── terraform.tf         # TF Cloud backend（workspace: platform-claudeflare）+ remote_state
├── provider.tf          # cloudflare / aws プロバイダ
├── variables.tf         # zone_id, allowed_ips, entra_* (sensitive) 等
├── access.tf            # IdP / Access application / policy
├── waf.tf               # IP 許可リスト ruleset
├── tunnel.tf            # Tunnel 本体 + ingress 設定
├── dns.tf               # os / mcp レコード
├── ec2.tf               # cloudflared + サンプル MCP ホスト
├── security.tf          # SG（egress のみ）
└── outputs.tf           # tunnel token（sensitive）、各ホスト名
```

## 4. 検証項目（Done の定義）

- [ ] 許可 IP 以外から `os.<ドメイン>` にアクセスできない（WAF が先に遮断）
- [ ] 許可 IP からのアクセスで Entra ログイン画面に飛び、対象グループのユーザーのみ通過できる
- [ ] Cloudflare OS 上でチャット・Gadget 作成ができ、成果物が永続する
- [ ] `gatekeeper-mcp` から Tunnel 経由でサンプル MCP のツールを呼び出せる（AWS 側 inbound 許可ゼロのまま）
- [ ] Gadget を別ユーザーに `use` ロールで共有でき、observer 検証が効く
- [ ] Gatekeeper のアクションジャーナルに MCP 呼び出しが記録されている

## 5. 本番（会社）構成との差分

| 項目 | 本サンプル | 本番提案 |
|---|---|---|
| Access 席数 | 無料枠（50席以内） | 300席（有償） |
| MCP 認可 | `gatekeeper-mcp`（エンドポイント直指定） | MCP Server Portal（Access ポリシーで認可） |
| LLM | Workers AI 無料枠 | Bedrock（AWS 請求） |
| ログ長期保存 | なし（ダッシュボード確認のみ） | Logpush → S3 + Access ログ pull |
| cloudflared | EC2 1台 | Fargate 冗長化 |
