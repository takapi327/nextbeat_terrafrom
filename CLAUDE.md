# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

AWS Organizations を使用したマルチアカウント Terraform インフラストラクチャ。Azure AD SSO と統合され、Terraform Cloud でステート管理を行う。

## アーキテクチャ

### アカウント構成
- **platform**: 共有インフラストラクチャアカウント（VPC、セキュリティ、IAM）
- **productA**: プロダクトA専用アカウント（ECS、CloudFront、WAF）
- **productB**: プロダクトB専用アカウント（Aurora検証環境）

### 主要技術スタック
- **サービスメッシュ**: AWS VPC Lattice
- **コンテナ**: Amazon ECS
- **データベース**: RDS、Aurora
- **CDN**: CloudFront
- **セキュリティ**: WAF、セキュリティグループ
- **監視**: CloudWatch Agent

## 開発コマンド

### 環境セットアップ
```bash
# tfenv インストール
brew install tfenv

# Terraform インストール（バージョンは .terraform-version に記載）
tfenv install
```

### デプロイ手順
1. AWS SSO ページにアクセスし、Azure AD 認証
2. 対象アカウントの「Command line or programmatic access」から環境変数をコピー
3. ターミナルに環境変数をペースト

```bash
# 初回のみ
terraform init

# 変更確認
terraform plan

# 変更適用
terraform apply
```

### Terraform Cloud 設定
- Organization: `takapi327`
- Workspaces:
  - `platform`: platform アカウント用
  - `productA`: productA アカウント用
  - `productA-cwagent`: productA の CloudWatch Agent 用
  - `productA-vpclattice`: productA の VPC Lattice 用
  - `productB`: productB アカウント用
  - `productB-aurora-verification`: productB の Aurora 検証環境用
  - `productB-vpclattice`: productB の VPC Lattice 用

## ディレクトリ構造

各アカウントディレクトリは独立したTerraformモジュールとして構成:
- `terraform.tf`: バックエンド設定（Terraform Cloud）
- `provider.tf`: AWS プロバイダー設定
- `variables.tf`: 入力変数定義
- リソース別 `.tf` ファイル（vpc.tf、ecs.tf など）

## 注意事項

- Terraform バージョン: 1.4.6（tfenv で管理）
- AWS プロバイダーバージョン: 4.67.0
- 各モジュールは独立したワークスペースで管理
- SSO 認証情報の有効期限に注意（デフォルト1時間）