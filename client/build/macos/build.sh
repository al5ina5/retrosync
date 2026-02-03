#!/usr/bin/env bash
# Build RetroSync macOS .app bundle (fused LÖVE game).
# Requires: zip, curl (for downloading LÖVE if needed), PlistBuddy (macOS).
#
# Usage: run from repo root or client/:
#   npm run client:build:macos
#   npm run client:build:macos -- --prod
#   # or: ./client/build/macos/build.sh --prod
#   # or: ./client/build/macos/build.sh --server-url https://retrosync.vercel.app
#
# Output: client/dist/macos/RetroSync.app and RetroSync.love
#
# Optional: set LOVE_APP to path to love.app to skip download, e.g.:
#   LOVE_APP=/Applications/love.app ./client/build/macos/build.sh

set -e

# --- Args / config ---
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
  # Trim trailing slash to keep API paths clean.
  if [[ "${url: -1}" == "/" ]]; then
    url="${url%/}"
  fi
  printf '%s' "$url"
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

# Must run on macOS (PlistBuddy, .app bundle)
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: This build is for macOS only. (PlistBuddy and .app bundle require macOS.)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Client root = parent of build/ (e.g. client/)
CLIENT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$CLIENT_ROOT/dist/macos"
APP_NAME="RetroSync"

# Fail fast if game files are missing
if [[ ! -f "$CLIENT_ROOT/main.lua" || ! -f "$CLIENT_ROOT/conf.lua" ]]; then
  echo "ERROR: main.lua or conf.lua not found in $CLIENT_ROOT" >&2
  exit 1
fi
LOVE_VERSION="11.5"
LOVE_RELEASE_URL="https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-macos.zip"
CACHE_DIR="${SCRIPT_DIR}/.cache"

mkdir -p "$OUT_DIR"
mkdir -p "$CACHE_DIR"

# --- 1. Create .love archive (game files at root of zip) ---
LOVE_FILE="$OUT_DIR/${APP_NAME}.love"
echo "Building ${APP_NAME}.love ..."
(cd "$CLIENT_ROOT" && zip -r -q "$LOVE_FILE" main.lua conf.lua assets lib src autostart watcher.sh)
echo "  -> $LOVE_FILE"

# --- 2. Resolve LÖVE app (use LOVE_APP env, or /Applications/love.app, or download) ---
LOVE_APP_PATH=""
if [[ -n "${LOVE_APP:-}" && -d "${LOVE_APP}" ]]; then
  LOVE_APP_PATH="${LOVE_APP}"
elif [[ -d "/Applications/love.app" ]]; then
  LOVE_APP_PATH="/Applications/love.app"
elif [[ -d "$CACHE_DIR/love.app" ]]; then
  LOVE_APP_PATH="$CACHE_DIR/love.app"
else
  echo "Downloading LÖVE ${LOVE_VERSION} for macOS..."
  ZIP_PATH="$CACHE_DIR/love-${LOVE_VERSION}-macos.zip"
  curl -sSfL -o "$ZIP_PATH" "$LOVE_RELEASE_URL"
  unzip -q -o "$ZIP_PATH" -d "$CACHE_DIR"
  if [[ -d "$CACHE_DIR/love.app" ]]; then
    LOVE_APP_PATH="$CACHE_DIR/love.app"
  elif [[ -d "$CACHE_DIR/love-${LOVE_VERSION}-macos/love.app" ]]; then
    LOVE_APP_PATH="$CACHE_DIR/love-${LOVE_VERSION}-macos/love.app"
  else
    echo "ERROR: Could not find love.app inside downloaded archive. Check $CACHE_DIR" >&2
    exit 1
  fi
  echo "  -> $LOVE_APP_PATH"
fi

# --- 3. Copy love.app -> RetroSync.app and add .love to Resources ---
APP_PATH="$OUT_DIR/${APP_NAME}.app"
rm -rf "$APP_PATH"
cp -R "$LOVE_APP_PATH" "$APP_PATH"
cp "$LOVE_FILE" "$APP_PATH/Contents/Resources/"
echo "Created $APP_PATH (fused with ${APP_NAME}.love)"

# Optionally bake server URL into config.json in app bundle (shared script; same structure on all builds)
if [[ -n "$SERVER_URL" ]]; then
  DATA_DIR="$APP_PATH/Contents/Resources/data"
  bash "$SCRIPT_DIR/../shared/write_config_json.sh" "$DATA_DIR" "$SERVER_URL"
  echo "Wrote server URL to $DATA_DIR/config.json"
else
  echo "No server URL override provided; client will use default from src/config.lua"
fi

# --- 4. Update Info.plist (bundle id, name, remove .love association) ---
PLIST="$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.retrosync.app" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :UTExportedTypeDeclarations" "$PLIST" 2>/dev/null || true
echo "Updated Info.plist (CFBundleIdentifier, CFBundleName, removed UTExportedTypeDeclarations)"

echo ""
echo "Done. Output:"
echo "  App:   $APP_PATH"
echo "  .love: $LOVE_FILE"
echo ""
echo "Open the app: open \"$APP_PATH\""
echo "(If macOS blocks it, right-click the app → Open → Open.)"
