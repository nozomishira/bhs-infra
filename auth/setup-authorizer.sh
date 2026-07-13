#!/bin/bash
# JWT Authorizer のセットアップスクリプト
# コンソールで作成した Authorizer を各ルートにアタッチする
# 初回のみ実行。CFn の EarlyValidation バグ回避のため CLI で管理。

set -e

REGION="ap-northeast-1"
API_NAME="dev-apne1-bhs-http-api"

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
  --query "Items[0].AuthorizerId" \
  --output text)

if [ -z "$AUTHORIZER_ID" ] || [ "$AUTHORIZER_ID" == "None" ]; then
  echo "No authorizer found. Creating one..."
  AUTHORIZER_ID=$(aws apigatewayv2 create-authorizer \
    --api-id "$API_ID" \
    --authorizer-type JWT \
    --name "dev-apne1-bhs-jwt-authorizer" \
    --identity-source '$request.header.Authorization' \
    --jwt-configuration Issuer=https://cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_dmazO6ydM,Audience=7lpdja1n1gf2qeeuf21j5enc58 \
    --region "$REGION" \
    --query "AuthorizerId" \
    --output text)
fi
echo "Authorizer ID: $AUTHORIZER_ID"

# 認証が必要なルートキー一覧
AUTH_ROUTES=("GET /levels" "GET /questions" "POST /sessions" "POST /chat" "GET /chat/scenarios" "POST /chat/evaluate")

# 全ルートを取得
echo "Fetching routes..."
ROUTES_JSON=$(aws apigatewayv2 get-routes --api-id "$API_ID" --region "$REGION" --output json)

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

  echo "  Attaching authorizer to: $ROUTE_KEY ($ROUTE_ID)"
  aws apigatewayv2 update-route \
    --api-id "$API_ID" \
    --route-id "$ROUTE_ID" \
    --authorization-type JWT \
    --authorizer-id "$AUTHORIZER_ID" \
    --region "$REGION" > /dev/null
done

echo ""
echo "Done! All routes updated with JWT authorizer."
