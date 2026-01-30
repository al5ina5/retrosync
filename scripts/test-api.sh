#!/bin/bash
# Test the /api/devices/code endpoint

echo "Testing POST /api/devices/code"
echo "================================"
echo ""

# Test with curl
RESPONSE=$(curl -s -X POST http://10.0.0.197:3002/api/devices/code \
  -H "Content-Type: application/json" \
  -d '{"deviceType":"miyoo_flip"}')

echo "Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Check if we got a code
CODE=$(echo "$RESPONSE" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
if [ -n "$CODE" ]; then
  echo "✓ Code generated: $CODE"
else
  echo "✗ Failed to get code"
  echo ""
  echo "Full response:"
  echo "$RESPONSE"
fi
