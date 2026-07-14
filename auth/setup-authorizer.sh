#!/bin/bash
# JWT Authorizer のセットアップスクリプト
# Authorizer を作成（または既存を使用）し、認証が必要なルートにアタッチする。
#
# 認証なし（誰でもアクセス可能）:
#   GET /health, GET /chat/health, GET /levels, GET /questions
#
# 認証あり（ログイン必須）:
#   POST /sessions, POST /chat, GET /chat/scenarios,
#   POST /chat/evaluate, POST /chat/history,
#   GET /chat/history, GET /chat/history/{sessionId}

set -e

REGION="ap-northeast-1"
API_NAME="dev-apne1-bhs-http-api"
COGNITO_USER_POOL_ID="ap-northeast-1_dmazO6ydM"
COGNITO_CLIENT_ID="7lpdja1n1gf2qeeuf21j5enc58"

# API ID を取得
echo "Fetching API ID..."
API_ID=$(aws apigatewayv2 get-apis \
  --region "$REGION" \
  --query "Items[?Name=='$API_NAME'].ApiId" \
  --output text)

if [ -z "$API_ID" ]; then
  echo "ERROR: API '$API_NAME' not found"
  exit 1
fi
echo "API ID: $API_ID"

# 既存の Authorizer を確認
echo "Fetching existing authorizers..."
AUTHORIZER_ID=$(aws apigatewayv2 get-authorizers \
  --api-id "$API_ID" \
  --region "$REGION" \
  --query "Items[?Name=='dev-apne1-bhs-jwt-authorizer'].AuthorizerId" \
  --output text)

if [ -z "$AUTHORIZER_ID" ] || [ "$AUTHORIZER_ID" == "None" ]; then
  echo "Creating JWT Authorizer..."
  AUTHORIZER_ID=$(aws apigatewayv2 create-authorizer \
    --api-id "$API_ID" \
    --authorizer-type JWT \
    --name "dev-apne1-bhs-jwt-authorizer" \
    --identity-source '$request.header.Authorization' \
    --jwt-configuration "Issuer=https://cognito-idp.${REGION}.amazonaws.com/${COGNITO_USER_POOL_ID},Audience=${COGNITO_CLIENT_ID}" \
    --region "$REGION" \
    --query "AuthorizerId" \
    --output text)
  echo "Created Authorizer: $AUTHORIZER_ID"
else
  echo "Using existing Authorizer: $AUTHORIZER_ID"
fi

# 認証が必要なルートキー一覧
AUTH_ROUTES=(
  "POST /sessions"
  "POST /chat"
  "GET /chat/scenarios"
  "POST /chat/evaluate"
  "POST /chat/history"
  "GET /chat/history"
  "GET /chat/history/{sessionId}"
)

# 認証不要にするルート（Authorizer を外す）
NO_AUTH_ROUTES=(
  "GET /health"
  "GET /chat/health"
  "GET /levels"
  "GET /questions"
)

# 全ルートを取得
echo ""
echo "Fetching routes..."
ROUTES_JSON=$(aws apigatewayv2 get-routes --api-id "$API_ID" --region "$REGION" --output json)

# 認証ありルートにアタッチ
echo ""
echo "=== Attaching Authorizer to protected routes ==="
for ROUTE_KEY in "${AUTH_ROUTES[@]}"; do
  ROUTE_ID=$(echo "$ROUTES_JSON" | python3 -c "
import sys, json
routes = json.load(sys.stdin)['Items']
for r in routes:
    if r['RouteKey'] == '$ROUTE_KEY':
        print(r['RouteId'])
        break
")

  if [ -z "$ROUTE_ID" ]; then
    echo "  SKIP: Route '$ROUTE_KEY' not found"
    continue
  fi

  echo "  AUTH: $ROUTE_KEY ($ROUTE_ID)"
  aws apigatewayv2 update-route \
    --api-id "$API_ID" \
    --route-id "$ROUTE_ID" \
    --authorization-type JWT \
    --authorizer-id "$AUTHORIZER_ID" \
    --region "$REGION" > /dev/null
done

# 認証なしルートから Authorizer を外す
echo ""
echo "=== Removing Authorizer from public routes ==="
for ROUTE_KEY in "${NO_AUTH_ROUTES[@]}"; do
  ROUTE_ID=$(echo "$ROUTES_JSON" | python3 -c "
import sys, json
routes = json.load(sys.stdin)['Items']
for r in routes:
    if r['RouteKey'] == '$ROUTE_KEY':
        print(r['RouteId'])
        break
")

  if [ -z "$ROUTE_ID" ]; then
    echo "  SKIP: Route '$ROUTE_KEY' not found"
    continue
  fi

  echo "  PUBLIC: $ROUTE_KEY ($ROUTE_ID)"
  aws apigatewayv2 update-route \
    --api-id "$API_ID" \
    --route-id "$ROUTE_ID" \
    --authorization-type NONE \
    --region "$REGION" > /dev/null
done

echo ""
echo "Done! Authorizer setup complete."
echo ""
echo "Protected routes (login required):"
printf '  %s\n' "${AUTH_ROUTES[@]}"
echo ""
echo "Public routes (no login):"
printf '  %s\n' "${NO_AUTH_ROUTES[@]}"
