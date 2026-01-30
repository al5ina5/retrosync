#!/bin/bash
# Test the deployed RetroSync API (https://retrosync.vercel.app) via curl

BASE_URL="${RETROSYNC_URL:-https://retrosync.vercel.app}"

echo "Testing deployed API: $BASE_URL"
echo ""

# 1. DB health check
echo "1. GET /api/debug/db-test"
echo "   ----------------------------------------"
DB_RESP=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "$BASE_URL/api/debug/db-test")
DB_BODY=$(echo "$DB_RESP" | sed '/^HTTP_STATUS:/d' | tr -d '\n')
DB_STATUS=$(echo "$DB_RESP" | grep '^HTTP_STATUS:' | cut -d: -f2)
echo "   Status: $DB_STATUS"
echo "   Body: $DB_BODY"
if [ "$DB_STATUS" = "200" ]; then
  echo "   ✓ DB health check OK"
else
  echo "   ✗ DB health check FAILED"
fi
echo ""

# 2. Device code generation (same as Miyoo client)
echo "2. POST /api/devices/code (deviceType: other)"
echo "   ----------------------------------------"
CODE_RESP=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$BASE_URL/api/devices/code" \
  -H "Content-Type: application/json" \
  -d '{"deviceType":"other"}')
CODE_BODY=$(echo "$CODE_RESP" | sed '/^HTTP_STATUS:/d' | tr -d '\n')
CODE_STATUS=$(echo "$CODE_RESP" | grep '^HTTP_STATUS:' | cut -d: -f2)
echo "   Status: $CODE_STATUS"
echo "   Body: $CODE_BODY"
if [ "$CODE_STATUS" = "200" ]; then
  CODE=$(echo "$CODE_BODY" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
  [ -n "$CODE" ] && echo "   ✓ Code generated: $CODE" || echo "   ✓ Code endpoint OK"
else
  echo "   ✗ Code generation FAILED"
fi
echo ""

echo "Done. Override URL with: RETROSYNC_URL=https://... ./test-deployed.sh"
