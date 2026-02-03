#!/usr/bin/env bash
# Build RetroSync Linux package (bundled LÖVE runtime).
# Requires: bash, curl, tar, zip.
#
# Usage: run from repo root or client/:
#   npm run client:build:linux
#   npm run client:build:linux -- --prod
#   # or: ./client/build/linux/build.sh --prod
#   # or: RETROSYNC_SERVER_URL=https://retrosync.vercel.app ./client/build/linux/build.sh
#
# Output: client/dist/linux/RetroSync (folder) and client/retrosync-linux.zip
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
require_cmd tar
require_cmd zip

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$CLIENT_ROOT/dist/linux"
PACKAGE_DIR="$OUT_DIR/RetroSync"
CACHE_DIR="$SCRIPT_DIR/.cache"
LOVE_VERSION="11.5"
LOVE_TAR="love-${LOVE_VERSION}-linux-x86_64.tar.gz"
LOVE_URL="https://github.com/love2d/love/releases/download/${LOVE_VERSION}/${LOVE_TAR}"

mkdir -p "$OUT_DIR"
mkdir -p "$CACHE_DIR"

LOVE_FILE="$OUT_DIR/RetroSync.love"

echo "=== RetroSync Linux Build ==="
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

TAR_CACHE_PATH="$CACHE_DIR/$LOVE_TAR"
RUNTIME_DIR="$CACHE_DIR/love-${LOVE_VERSION}-linux-x86_64"

echo "[2/5] Ensuring LÖVE runtime (${LOVE_VERSION}) ..."
if [[ ! -f "$TAR_CACHE_PATH" ]]; then
  echo "  Downloading $LOVE_URL"
  curl -sSfL -o "$TAR_CACHE_PATH" "$LOVE_URL"
else
  echo "  Using cached archive $TAR_CACHE_PATH"
fi

echo "[3/5] Preparing runtime ..."
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR"
tar -xzf "$TAR_CACHE_PATH" -C "$CACHE_DIR"

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -R "$RUNTIME_DIR"/. "$PACKAGE_DIR"/

if [[ -f "$PACKAGE_DIR/love" ]]; then
  mv "$PACKAGE_DIR/love" "$PACKAGE_DIR/RetroSync.bin"
fi

if [[ -f "$PACKAGE_DIR/lovec" ]]; then
  rm "$PACKAGE_DIR/lovec"
fi
chmod +x "$PACKAGE_DIR/RetroSync.bin"

echo "[4/5] Adding launch scripts ..."
cp "$LOVE_FILE" "$PACKAGE_DIR/RetroSync.love"

cat > "$PACKAGE_DIR/RetroSync.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$SCRIPT_DIR/RetroSync.bin" "$SCRIPT_DIR/RetroSync.love" "$@"
EOF
chmod +x "$PACKAGE_DIR/RetroSync.sh"

if [[ -n "$SERVER_URL" ]]; then
  mkdir -p "$PACKAGE_DIR/data"
  printf '%s' "$SERVER_URL" > "$PACKAGE_DIR/data/server_url"
  echo "  Baked server URL into data/server_url"
fi

cat > "$PACKAGE_DIR/README.txt" <<'EOF'
RetroSync for Linux
===================

Contents:
  RetroSync.sh        - Launch script (recommended)
  RetroSync.bin       - Bundled LÖVE runtime (x86_64)
  RetroSync.love      - Game archive (for troubleshooting)
  lib/                - Required shared libraries

Usage:
  1. Extract this folder anywhere.
  2. Run ./RetroSync.sh
     (you may need to run: chmod +x RetroSync.sh)
  3. Pair the app using a code from retrosync.vercel.app.

Optional:
  - Create a desktop entry that calls RetroSync.sh if you want a launcher.
EOF

echo "[5/5] Creating ZIP archive ..."
ZIP_OUTPUT="$CLIENT_ROOT/retrosync-linux.zip"
rm -f "$ZIP_OUTPUT"
(cd "$OUT_DIR" && zip -r -q "$ZIP_OUTPUT" RetroSync)
echo "  -> $ZIP_OUTPUT"

echo ""
echo "Done."
echo "  Folder: $PACKAGE_DIR"
echo "  ZIP:    $ZIP_OUTPUT"
