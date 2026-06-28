# ADR-001: CICD戦略

## ステータス
承認済み

## 日付
2026-06-25

## コンテキスト
bhs-indonesia-webappはNext.jsで構築された静的サイトで、S3+CloudFrontで配信している。
developブランチへのマージをトリガーとした自動デプロイの仕組みが必要。

## 検討した選択肢

### 1. GitHub Actions
- GitHubネイティブのCI/CDサービス
- 無料枠あり（月2000分）
- developブランチへのマージトリガーがネイティブ対応
- yamlファイルをgitで管理できる

### 2. AWS CodePipeline
- AWSネイティブのCI/CDサービス
- 月$1/パイプライン + 実行コスト
- GitHubトリガーにWebhookの設定が必要
- CFnが複雑になる

## 決定
**GitHub Actionsを採用する**

## 理由
- developブランチへのマージトリガーがシンプルに設定できる
- 無料枠でコストを抑えられる
- yamlファイルをgitで管理できるためIaCの方針に沿っている

## AWSとの認証方式

### 検討した選択肢
1. **OIDC（採用）**: AWSとGitHubが一時的なトークンで認証。アクセスキー不要でセキュア
2. **アクセスキー**: GitHubのSecretsにAWSキーを保存。漏洩リスクあり

### 決定
**OIDCを採用する**

## 理由
- アクセスキーをGitHubに保存しなくて済むためセキュリティリスクが低い
- AWSのベストプラクティスに沿っている

## 構成

developブランチにマージ

↓

GitHub Actions (deploy.yml)

↓

npm run build

↓

aws s3 sync → S3バケット

↓

CloudFront invalidation


## 影響
- bhs-webappリポジトリに `.github/workflows/deploy.yml` を追加
- bhs-infraリポジトリにOIDC用CFnテンプレート `cicd/oidc.yml` を追加
- AWSにOIDCプロバイダーとIAMロールを作成

## 参照
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Identity Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)