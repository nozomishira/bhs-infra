# bhs-infra

bhs-indonesia-webappのインフラをCloudFormationで管理するリポジトリ。

---

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

### deploy（推奨）

新規作成・更新どちらも同じコマンドで実行できる。

```bash
aws cloudformation deploy \
  --stack-name <スタック名> \
  --template-file <テンプレートファイルのパス> \
  --region ap-northeast-1
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

### 空実行（変更内容の確認）

```bash
aws cloudformation deploy \
  --stack-name <スタック名> \
  --template-file <テンプレートファイルのパス> \
  --region ap-northeast-1 \
  --no-execute-changeset
```

### スタックの出力値を確認

```bash
aws cloudformation describe-stacks \
  --stack-name <スタック名> \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs"
```

### スタックの削除

```bash
aws cloudformation delete-stack \
  --stack-name <スタック名> \
  --region ap-northeast-1
```

---

## このリポジトリのスタック一覧

| スタック名 | テンプレート | 内容 | 備考 |
|---|---|---|---|
| `{env}-bhs-indonesia-webapp` | webapp/webapp.yml | S3 + CloudFront | |
| `{env}-bhs-indonesia-cicd` | cicd/oidc.yml | OIDC + IAMロール | `--capabilities CAPABILITY_NAMED_IAM` 必要 |
| `{env}-bhs-indonesia-database` | database/database.yml | DynamoDB テーブル | |
| `{env}-bhs-indonesia-webapi` | webapi/webapi.yml | API Gateway + Lambda (quiz-api) | `--capabilities CAPABILITY_NAMED_IAM` 必要 |

> `{env}` は `dev` / `test` / `prod` に読み替えてください

### Lambda 命名規則

Lambda は機能ドメインごとに分割する方針。現在は `quiz-api` のみ。

| Lambda 名 | 用途 | コードの場所 |
|---|---|---|
| `{prefix}-bhs-quiz-api` | 問題取得・セッション記録 | bhs-webapi/packages/quiz-api |
| `{prefix}-bhs-chat-api` | Bedrock 会話AI（将来） | bhs-webapi/packages/chat-api |
| `{prefix}-bhs-voice-api` | Bedrock 発音チェック（将来） | bhs-webapi/packages/voice-api |

---

## デプロイ順序

```
1. webapp  (S3/CloudFront)
2. cicd    (OIDC/IAM)
3. database (DynamoDB)
4. webapi  (API Gateway / Lambda) ← database の後に実行
```

---

## 各スタックのデプロイコマンド

### webapp.yml

```bash
# 空実行
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-webapp \
  --template-file ./webapp/webapp.yml \
  --parameter-overrides file://webapp/parameter-dev.json \
  --region ap-northeast-1 \
  --no-execute-changeset

# 変更デプロイ
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-webapp \
  --template-file ./webapp/webapp.yml \
  --parameter-overrides file://webapp/parameter-dev.json \
  --region ap-northeast-1
```

### cicd/oidc.yml

> 2つの IAM ロールを作成する:
> - `{prefix}-github-actions-webapp-role` : bhs-webapp → S3/CloudFront デプロイ用
> - `{prefix}-github-actions-webapi-role` : bhs-webapi → Lambda デプロイ用

```bash
# 空実行
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-cicd \
  --template-file ./cicd/oidc.yml \
  --parameter-overrides file://cicd/parameter-dev.json \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-execute-changeset

# 変更デプロイ
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-cicd \
  --template-file ./cicd/oidc.yml \
  --parameter-overrides file://cicd/parameter-dev.json \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

デプロイ後、各ロールの ARN を確認:

```bash
# webapp ロール ARN
aws cloudformation describe-stacks \
  --stack-name dev-bhs-indonesia-cicd \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs[?OutputKey=='GitHubActionsWebAppRoleArn'].OutputValue" \
  --output text

# webapi ロール ARN
aws cloudformation describe-stacks \
  --stack-name dev-bhs-indonesia-cicd \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs[?OutputKey=='GitHubActionsWebApiRoleArn'].OutputValue" \
  --output text
```

### database/database.yml

```bash
# 空実行
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-database \
  --template-file ./database/database.yml \
  --parameter-overrides file://database/parameter-dev.json \
  --region ap-northeast-1 \
  --no-execute-changeset

# 変更デプロイ
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-database \
  --template-file ./database/database.yml \
  --parameter-overrides file://database/parameter-dev.json \
  --region ap-northeast-1
```

### webapi/webapi.yml

> Lambda の実行ロール（IAM）を含むため `--capabilities CAPABILITY_NAMED_IAM` が必要
> Lambda 名: `{prefix}-bhs-quiz-api`

```bash
# 空実行
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-webapi \
  --template-file ./webapi/webapi.yml \
  --parameter-overrides file://webapi/parameter-dev.json \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-execute-changeset

# 変更デプロイ
aws cloudformation deploy \
  --stack-name dev-bhs-indonesia-webapi \
  --template-file ./webapi/webapi.yml \
  --parameter-overrides file://webapi/parameter-dev.json \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

---

## 環境別パラメータファイル

各ディレクトリに `parameter-dev.json` / `parameter-test.json` / `parameter-prod.json` を配置。

| 環境 | Prefix | Branch |
|---|---|---|
| dev | `dev-apne1` | `develop` |
| test | `test-apne1` | `test` |
| prod | `prod-apne1` | `main` |

---

## API エンドポイントの確認

webapi スタックのデプロイ後、エンドポイント URL を確認:

```bash
aws cloudformation describe-stacks \
  --stack-name dev-bhs-indonesia-webapi \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
  --output text
```

quiz-api の Lambda 関数名を確認:

```bash
aws cloudformation describe-stacks \
  --stack-name dev-bhs-indonesia-webapi \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs[?OutputKey=='QuizApiFunctionName'].OutputValue" \
  --output text
```

---

## 注意事項

- DynamoDB テーブルの削除は即座にデータが消える。`delete-stack` 前に必ずバックアップを確認
- prod 環境では PITR（ポイントインタイムリカバリ）が自動的に有効になる
- webapi の Lambda コードは CI/CD でデプロイ。このテンプレートにはプレースホルダーのみ含む
- prod の `WebAppOrigin` は CloudFront ドメインを `parameter-prod.json` に設定すること
