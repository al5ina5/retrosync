#!/bin/bash
# Write minimal config.json to a directory. Used by all builds for unified config.
# Usage: write_config_json.sh <output_dir> [server_url]
#   output_dir: directory to write config.json into (created if needed).
#   server_url: optional; if unset uses DEFAULT_SERVER_URL from vars.sh or https://retrosync.vercel.app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vars.sh"

OUT_DIR="${1:?usage: write_config_json.sh <output_dir> [server_url]}"
SERVER_URL="${2:-$DEFAULT_SERVER_URL}"
SERVER_URL="${SERVER_URL%/}"

mkdir -p "$OUT_DIR"
if command -v jq >/dev/null 2>&1; then
  jq -n --arg url "$SERVER_URL" '{serverUrl: $url, autostart: false}' > "$OUT_DIR/config.json"
else
  printf '{"serverUrl":"%s","autostart":false}\n' "$SERVER_URL" > "$OUT_DIR/config.json"
fi
