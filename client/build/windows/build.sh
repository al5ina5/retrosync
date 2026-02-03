#!/usr/bin/env bash
# Build RetroSync Windows package (fused LÖVE runtime).
# Requires: bash, curl, unzip, zip, sed, cat.
#
# Usage: run from repo root or client/:
#   npm run client:build:windows
#   npm run client:build:windows -- --prod
#   # or: ./client/build/windows/build.sh --prod
#   # or: RETROSYNC_SERVER_URL=https://retrosync.vercel.app ./client/build/windows/build.sh
#
# Output: client/dist/windows/RetroSync (folder) and client/retrosync-windows.zip
#
# Optional: set RETROSYNC_SERVER_URL or pass --prod/--dev/--server-url.

set -euo pipefail

DEFAULT_SERVER_URL_PROD="https://retrosync.vercel.app"
DEFAULT_SERVER_URL_DEV="http://localhost:3000"
SERVER_URL="${RETROSYNC_SERVER_URL:-}"

usage() {
  cat <<EOF
Usage: $0 [--prod|--dev|--server-url <url>]

Options:
  --prod               Use production server URL (${DEFAULT_SERVER_URL_PROD})
  --dev                Use local dev server URL (${DEFAULT_SERVER_URL_DEV})
  --server-url <url>   Use a custom server URL (overrides env)
  -h, --help           Show this help

You can also set RETROSYNC_SERVER_URL in the environment.
EOF
}

normalize_url() {
  local url="$1"
  if [[ "${url: -1}" == "/" ]]; then
    url="${url%/}"
  fi
  printf '%s' "$url"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Missing required command: $1" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)
      SERVER_URL="$DEFAULT_SERVER_URL_PROD"
      shift
      ;;
    --dev)
      SERVER_URL="$DEFAULT_SERVER_URL_DEV"
      shift
      ;;
    --server-url)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "ERROR: --server-url requires a value" >&2
        usage
        exit 1
      fi
      SERVER_URL="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$SERVER_URL" ]]; then
  SERVER_URL="$(normalize_url "$SERVER_URL")"
fi

require_cmd curl
require_cmd unzip
require_cmd zip

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$CLIENT_ROOT/dist/windows"
PACKAGE_DIR="$OUT_DIR/RetroSync"
CACHE_DIR="$SCRIPT_DIR/.cache"
LOVE_VERSION="11.5"
LOVE_ZIP="love-${LOVE_VERSION}-win64.zip"
LOVE_URL="https://github.com/love2d/love/releases/download/${LOVE_VERSION}/${LOVE_ZIP}"

mkdir -p "$OUT_DIR"
mkdir -p "$CACHE_DIR"

LOVE_FILE="$OUT_DIR/RetroSync.love"

echo "=== RetroSync Windows Build ==="
echo "Output directory: $PACKAGE_DIR"
echo ""

echo "[1/5] Creating RetroSync.love ..."
(
  cd "$CLIENT_ROOT"
  zip -r -q "$LOVE_FILE" \
    main.lua \
    conf.lua \
    assets \
    lib \
    src \
    autostart \
    watcher.sh
)
echo "  -> $LOVE_FILE"

ZIP_CACHE_PATH="$CACHE_DIR/$LOVE_ZIP"
RUNTIME_DIR="$CACHE_DIR/love-${LOVE_VERSION}-win64"

echo "[2/5] Ensuring LÖVE runtime (${LOVE_VERSION}) ..."
if [[ ! -f "$ZIP_CACHE_PATH" ]]; then
  echo "  Downloading $LOVE_URL"
  curl -sSfL -o "$ZIP_CACHE_PATH" "$LOVE_URL"
else
  echo "  Using cached archive $ZIP_CACHE_PATH"
fi

echo "[3/5] Preparing runtime ..."
rm -rf "$RUNTIME_DIR"
unzip -q "$ZIP_CACHE_PATH" -d "$CACHE_DIR"

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -R "$RUNTIME_DIR"/. "$PACKAGE_DIR"/

echo "[4/5] Fusing executable ..."
if [[ ! -f "$PACKAGE_DIR/love.exe" ]]; then
  echo "ERROR: love.exe not found in runtime package" >&2
  exit 1
fi
cat "$PACKAGE_DIR/love.exe" "$LOVE_FILE" > "$PACKAGE_DIR/RetroSync.exe"
rm "$PACKAGE_DIR/love.exe"

if [[ -f "$PACKAGE_DIR/lovec.exe" ]]; then
  cat "$PACKAGE_DIR/lovec.exe" "$LOVE_FILE" > "$PACKAGE_DIR/RetroSync-console.exe"
  rm "$PACKAGE_DIR/lovec.exe"
fi

if [[ -f "$PACKAGE_DIR/love.ico" ]]; then
  cp "$PACKAGE_DIR/love.ico" "$PACKAGE_DIR/RetroSync.ico"
fi

cp "$LOVE_FILE" "$PACKAGE_DIR/RetroSync.love"

# Seed config.json (shared script; same structure on all builds)
bash "$SCRIPT_DIR/../shared/write_config_json.sh" "$PACKAGE_DIR/data" "${SERVER_URL:-}"
if [[ -n "$SERVER_URL" ]]; then
  echo "  Baked server URL into data/config.json"
else
  echo "  Seeded default data/config.json"
fi

cat > "$PACKAGE_DIR/README.txt" <<'EOF'
RetroSync for Windows
=====================

Contents:
  RetroSync.exe           - Launch RetroSync (no console)
  RetroSync-console.exe   - Launch with console window
  RetroSync.love          - Game archive (for troubleshooting)
  *.dll / *.txt           - Required LÖVE runtime files

Usage:
  1. Extract this folder anywhere.
  2. Double-click RetroSync.exe (or RetroSync-console.exe to see logs).
  3. Pair the app using a code from retrosync.vercel.app.

If you see smart screen warnings, choose "More info" → "Run anyway".
EOF

echo "[5/5] Creating ZIP archive ..."
ZIP_OUTPUT="$CLIENT_ROOT/retrosync-windows.zip"
rm -f "$ZIP_OUTPUT"
(cd "$OUT_DIR" && zip -r -q "$ZIP_OUTPUT" RetroSync)
echo "  -> $ZIP_OUTPUT"

echo ""
echo "Done."
echo "  Folder: $PACKAGE_DIR"
echo "  ZIP:    $ZIP_OUTPUT"
