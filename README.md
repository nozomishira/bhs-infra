# BHS Webapp Infrastructure

Terraform で AWS インフラを管理するプロジェクト。

## 📁 ディレクトリ構成

```
bhs-infra/
├── database/          # DynamoDB テーブル定義
├── webapi/            # Lambda + API Gateway
├── webapp/            # S3 + CloudFront
├── init/              # セットアップスクリプト
└── terraform.tfvars   # 共通変数設定
```

## 🚀 クイックスタート

### 1. 初期化（一度だけ実行）

```bash
cd /home/shiranozo/bhs-infra
./init/setup.sh
```

### 2. AWS 認証設定

```bash
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region: ap-northeast-1
# Default output format: json
```

### 3. 各モジュールをデプロイ

**step 1: Database 作成**
```bash
cd database
terraform plan
terraform apply
```

出力から テーブル名を確認:
- `quiz_progress_table_name`
- `quiz_data_table_name`

**step 2: WebAPI デプロイ**
```bash
cd ../webapi

# terraform.tfvars で dynamodb テーブル名を指定
terraform plan -var 'dynamodb_quiz_progress_table=bhs-webapp-quiz-progress' \
               -var 'dynamodb_quiz_data_table=bhs-webapp-quiz-data'

terraform apply -var 'dynamodb_quiz_progress_table=bhs-webapp-quiz-progress' \
                -var 'dynamodb_quiz_data_table=bhs-webapp-quiz-data'
```

出力から API エンドポイントを確認:
- `api_endpoint`

**step 3: Webapp デプロイ**
```bash
cd ../webapp
terraform plan
terraform apply
```

出力から CloudFront ドメインを確認:
- `cloudfront_domain_name`

## 📝 設定

### terraform.tfvars（共通設定）

```hcl
aws_region         = "ap-northeast-1"
environment        = "dev"
app_name           = "bhs-webapp"
allowed_ips        = []  # IP制限用：["203.0.113.0/32"] など
cloudwatch_log_retention_days = 1
```

## 🔐 IP 制限の設定

開発中は誰でもアクセス可能、本番運用時に IP制限を追加：

```bash
# terraform.tfvars で設定
allowed_ips = ["203.0.113.0/32"]  # 自分の IP

# または環境変数で指定
terraform apply -var 'allowed_ips=["203.0.113.0/32"]'
```

## 📊 リソース確認

```bash
# デプロイ済みリソース確認
terraform show

# CloudFormation スタック確認
aws cloudformation list-stacks

# S3 バケット確認
aws s3 ls

# Lambda 関数確認
aws lambda list-functions

# DynamoDB テーブル確認
aws dynamodb list-tables

# API Gateway 確認
aws apigateway get-rest-apis
```

## 🗑️ クリーンアップ

```bash
# 逆順で削除（Webapp → WebAPI → Database）
cd webapp && terraform destroy
cd ../webapi && terraform destroy
cd ../database && terraform destroy
```

## ⚠️ 注意点

- **複数環境**: 別の環境（staging, prod）を作る場合は、フォルダをコピーして `terraform.tfvars` の `environment` を変更
- **State ファイル**: ローカル管理。本番運用では S3 バックエンド推奨
- **Lambda コード**: `webapi/lambda_placeholder.zip` はプレースホルダー。本開発コードで置き換え予定
