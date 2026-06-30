# bhs-infra

bhs-indonesia-webappのインフラをCloudFormationで管理するリポジトリ。
## 前提条件

- AWS CLIがインストール済みであること
- `aws configure` でアクセスキーとリージョンが設定済みであること

```bash
aws configure
# AWS Access Key ID: xxxxxxxx
# AWS Secret Access Key: xxxxxxxx
# Default region name: ap-northeast-1
# Default output format: json
```

---

## CloudFormationの適用方法

### スタックの新規作成

```bash
aws cloudformation create-stack \
  --stack-name <スタック名> \
  --template-body file://<テンプレートファイルのパス> \
  --region ap-northeast-1
```

### スタックの更新

```bash
aws cloudformation update-stack \
  --stack-name <スタック名> \
  --template-body file://<テンプレートファイルのパス> \
  --region ap-northeast-1
```

### create-stackとupdate-stackをまとめて使うdeploy（推奨）

新規作成・更新どちらも同じコマンドで実行できるため、基本的にはdeployを使う。

```bash
aws cloudformation deploy \
  --stack-name <スタック名> \
  --template-file <テンプレートファイルのパス> \
  --region ap-northeast-1
```

### パラメーターを渡す場合

```bash
aws cloudformation deploy \
  --stack-name <スタック名> \
  --template-file <テンプレートファイルのパス> \
  --region ap-northeast-1 \
  --parameter-overrides Prefix=prod-apne1
```

### IAMリソースを含む場合

IAMロールやポリシーを作成するテンプレートには `--capabilities` が必要。

```bash
aws cloudformation deploy \
  --stack-name <スタック名> \
  --template-file <テンプレートファイルのパス> \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

### スタックの出力値を確認

```bash
aws cloudformation describe-stacks \
  --stack-name <スタック名> \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs"
```

### スタックの削除


aws cloudformation delete-stack \
  --stack-name <スタック名> \
  --region


  ## このリポジトリのスタック一覧

| スタック名 | テンプレート | 内容 | 備考 |
|---|---|---|---|
| dev-bhs-indonesia-webapp | webapp/webapp.yml | S3 + CloudFront | |
| dev-bhs-indonesia-cicd | cicd/oidc.yml | OIDC + IAMロール | `--capabilities CAPABILITY_NAMED_IAM` が必要 |

## 各スタックのデプロイコマンド

### webapp.yml

```bash
##空実行

aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-webapp \
  --template-file ./webapp/webapp.yml \
  --parameter-overrides file://webapp/parameter-dev.json \
  --region ap-northeast-1
　--no-execute-changeset

## 変更デプロイ

aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-webapp \
  --template-file ./webapp/webapp.yml \
  --parameter-overrides file://webapp/parameter-dev.json \
  --region ap-northeast-1
```

### oidc.yml

```bash

##空実行

aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-cicd \
  --template-file ./cicd/oidc.yml \
  --parameter-overrides file://cicd/parameter-dev.json \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM
　--no-execute-changeset

## 変更デプロイ
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-cicd \
  --template-file ./cicd/oidc.yml \
  --parameter-overrides file://cicd/parameter-dev.json \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM
```