#!/usr/bin/env bash
# Run RetroSync macOS client for testing: dev (source + localhost) or prod (built .app).
#
# Usage:
#   yarn client:test:macos              # run source with localhost
#   yarn client:test:macos -- --prod    # open built production app (builds if missing)

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/client"
APP_PATH="$CLIENT/dist/macos/RetroSync.app"

if [[ "${1:-}" == "--prod" ]]; then
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Production app not found. Building with --prod..."
    (cd "$CLIENT" && ./build/macos/build.sh --prod)
  fi
  echo "Opening production app: $APP_PATH"
  open "$APP_PATH"
else
  cd "$CLIENT" && RETROSYNC_SERVER_URL=http://localhost:3000 love .
fi
