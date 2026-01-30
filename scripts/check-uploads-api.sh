#!/bin/bash
# check-uploads-api.sh - Verify device uploads via API (same auth as client)
#
# Uses the device API key from client/data/api_key to call GET /api/saves.
# If you see saves here but not in the dashboard, ensure you're logged into
# the dashboard with the SAME user account that paired this device.
#
# Usage:
#   ./scripts/check-uploads-api.sh
#   BASE_URL=https://retrosync.vercel.app ./scripts/check-uploads-api.sh
#   BASE_URL=http://localhost:3000 ./scripts/check-uploads-api.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_KEY_FILE="$REPO_ROOT/client/data/api_key"
if [[ ! -f "$API_KEY_FILE" ]]; then
  API_KEY_FILE="$REPO_ROOT/data/api_key"
fi

BASE_URL="${BASE_URL:-https://retrosync.vercel.app}"
BASE_URL="${BASE_URL%/}"

if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "ERROR: No API key file found at client/data/api_key or data/api_key"
  echo "Pair the device in the RetroSync app first, then run this script."
  exit 1
fi

API_KEY="$(head -n 1 "$API_KEY_FILE" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [[ -z "$API_KEY" ]]; then
  echo "ERROR: API key file is empty"
  exit 1
fi

echo "=== RetroSync: Check uploads via API ==="
echo "BASE_URL: $BASE_URL"
echo "API key:  ${API_KEY:0:8}...${API_KEY: -4}"
echo ""

# GET /api/saves with x-api-key (same as client)
RESPONSE="$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/saves" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json")"

HTTP_CODE="$(echo "$RESPONSE" | tail -n 1)"
HTTP_BODY="$(echo "$RESPONSE" | sed '$d')"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "API returned HTTP $HTTP_CODE"
  echo "$HTTP_BODY" | python3 -m json.tool 2>/dev/null || echo "$HTTP_BODY"
  if [[ "$HTTP_CODE" == "401" ]]; then
    echo ""
    echo "=> Invalid or expired API key. Re-pair the device in the app."
  fi
  exit 1
fi

# Parse count from success response
COUNT="$(echo "$HTTP_BODY" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('success') and 'data' in d:
        saves = d['data'].get('saves', [])
        print(len(saves))
    else:
        print(0)
except Exception:
    print(0)
" 2>/dev/null || echo "0")"

echo "Saves visible to this device's user: $COUNT"
echo ""

if [[ "$COUNT" -eq 0 ]]; then
  echo "=> No saves found. Possible reasons:"
  echo "   - Uploads failed (check client data/debug.log and data/watcher.log)"
  echo "   - Device is paired to a different user than the one in the dashboard"
  echo "   - Server URL mismatch (client server_url vs BASE_URL here)"
  echo ""
  echo "Full response:"
  echo "$HTTP_BODY" | python3 -m json.tool 2>/dev/null || echo "$HTTP_BODY"
  exit 0
fi

echo "Sample (first 3 saves):"
echo "$HTTP_BODY" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('success') and 'data' in d:
        for s in d['data'].get('saves', [])[:3]:
            print('  -', s.get('displayName', s.get('saveKey', '?')), '|', s.get('fileSize', 0), 'bytes')
except Exception:
    pass
" 2>/dev/null

echo ""
echo "=> If the dashboard shows no saves, log in with the SAME user account that paired this device."
exit 0
