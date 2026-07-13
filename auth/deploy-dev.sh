#!/bin/bash
# auth スタックのデプロイスクリプト (dev環境)
# Secrets Manager から Google OAuth credentials を取得して CFn に渡す

set -e

STACK_NAME="dev-bhs-indonesia-auth"
TEMPLATE_FILE="./auth/auth.yml"
REGION="ap-northeast-1"
SECRET_NAME="bhs/google-oauth"

echo "Fetching Google OAuth credentials from Secrets Manager..."

GOOGLE_CLIENT_ID=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" \
  --query "SecretString" \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['client_id'])")

GOOGLE_CLIENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" \
  --query "SecretString" \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['client_secret'])")

if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
  echo "ERROR: Failed to fetch credentials from Secrets Manager ($SECRET_NAME)"
  exit 1
fi

echo "Credentials fetched successfully."
echo "Deploying $STACK_NAME..."

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides \
    Prefix=dev-apne1 \
    Env=dev \
    GoogleClientId="$GOOGLE_CLIENT_ID" \
    GoogleClientSecret="$GOOGLE_CLIENT_SECRET" \
    CallbackUrl=https://d3oi52j21x9aqt.cloudfront.net/auth/callback \
    LogoutUrl=https://d3oi52j21x9aqt.cloudfront.net \
  --region "$REGION"

echo ""
echo "Done. Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs" \
  --output table
