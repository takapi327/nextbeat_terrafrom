# AWS Organizations for takapi327

## 目次

- [環境構築](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E7%92%B0%E5%A2%83%E6%A7%8B%E7%AF%89)
  - [tfenvのインストール](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#tfenv%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)
  - [Terraformのインストール](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#terraform%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)
- [AWS Organizations構成環境](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#aws-organizations%E6%A7%8B%E6%88%90%E7%92%B0%E5%A2%83)
  - [構築手順](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E6%A7%8B%E7%AF%89%E6%89%8B%E9%A0%86)
- [デプロイ手順](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E3%83%87%E3%83%97%E3%83%AD%E3%82%A4%E6%89%8B%E9%A0%86)
- [規約](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E8%A6%8F%E7%B4%84)
  - [ディレクトリ構造](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E3%83%87%E3%82%A3%E3%83%AC%E3%82%AF%E3%83%88%E3%83%AA%E6%A7%8B%E9%80%A0)
  - [ファイル命名規則](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E5%91%BD%E5%90%8D%E8%A6%8F%E5%89%87)
  - [コーディング規約](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E3%82%B3%E3%83%BC%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0%E8%A6%8F%E7%B4%84)
  - [IPアドレス規則](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#ip%E3%82%A2%E3%83%89%E3%83%AC%E3%82%B9%E8%A6%8F%E5%89%87)
- [アカウント一覧](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#%E3%82%A2%E3%82%AB%E3%82%A6%E3%83%B3%E3%83%88%E4%B8%80%E8%A6%A7)
  - [Sample Angular SSR](https://github.com/takapi327/terraform/tree/feature/2021-05-Create-takapi327-account-in-terraform#sample-angular-ssr)

## 環境構築

### tfenvのインストール

tfenvは複数バージョンのTerraformを利用する場合に役立つコマンドです。
また、利用バージョンを切り替えることなく、ルートディレクトリの.terraform-versionファイルに記載されているバージョンを優先して利用してくれる。

brewでインストールを行う
```
$ brew install tfenv
```

### Terraformのインストール

tfenvがインストールされていることが前提です。
バージョンを指定してインストールを行う。

```
$ tfenv install <version>
```

## AWS Organizations構成環境

AWS OrganizationsとAWS SSO、Azure ADを連携してアカウント・プロジェクト・環境ごとに管理、運用を行う。

![image](https://user-images.githubusercontent.com/57429437/118384012-ec616c00-b63d-11eb-9691-39248b84eba2.png)

### 構築手順

[Azure AD と AWS SSOの連携](https://fu3ak1.hatenablog.com/entry/2020/12/20/000622)

## Terraform Cloud

TerraformのStateファイルはTerraform Cloudで管理しています。

## デプロイ手順

SSOの認証情報を用いてTerraformを実行する

1. [Single Sign-On](https://d-95671f160a.awsapps.com/start#/)ページにアクセス
2. Azure AD認証(ログイン済みの場合はなし)
3. 任意のアカウント・プロジェクト・環境を選択
4. 任意の権限で、「Command line or programmatic access」を選択し、「Option 1: Set AWS environment variables」から環境変数をコピー
5. 実行したいTerraformのプロジェクト直下のコンソールで、コピーした環境変数を設定(ペースト)
6. terraform init実行(初回のみ)
7. terraform plan or apply 実行

![スクリーンショット 2021-05-16 12 06 49](https://user-images.githubusercontent.com/57429437/118384205-339c2c80-b63f-11eb-9601-7ec5492382e7.png)
