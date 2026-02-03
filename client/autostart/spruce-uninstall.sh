#!/bin/sh
# Uninstall RetroSync background watcher integration from spruceOS
set -u

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="${2:-$APPDIR/saves/love/retrosync}"
CONFIG_JSON="$DATA_DIR/config.json"

SPRUCEROOT="/mnt/SDCARD/spruce"
NETWORK_SVC="$SPRUCEROOT/scripts/networkservices.sh"
BACKUP="$NETWORK_SVC.retrosync.bak"
RETROFUNC_DIR="$SPRUCEROOT/bin/RetroSync"
RETROFUNC="$RETROFUNC_DIR/retrosyncFunctions.sh"

# Stop watcher via functions if available
if [ -f "$RETROFUNC" ]; then
  # shellcheck disable=SC1090
  . "$RETROFUNC"
  if command -v stop_retrosync_process >/dev/null 2>&1; then
    stop_retrosync_process || true
  fi
fi

# Restore original networkservices.sh if backup exists
if [ -f "$BACKUP" ]; then
  cp "$BACKUP" "$NETWORK_SVC"
  rm -f "$BACKUP"
fi

# Remove RetroSync functions file and directory if empty
rm -f "$RETROFUNC"
rmdir "$RETROFUNC_DIR" 2>/dev/null || true

# Mark autostart disabled in config.json (single source of truth)
if command -v jq >/dev/null 2>&1 && [ -f "$CONFIG_JSON" ]; then
  jq '.autostart = false' "$CONFIG_JSON" > "$CONFIG_JSON.tmp" && mv "$CONFIG_JSON.tmp" "$CONFIG_JSON"
else
  [ -f "$CONFIG_JSON" ] && printf '%s' "$(sed 's/"autostart"[[:space:]]*:[[:space:]]*"spruceos"/"autostart":false/' "$CONFIG_JSON")" > "$CONFIG_JSON.tmp" && mv "$CONFIG_JSON.tmp" "$CONFIG_JSON" 2>/dev/null || true
fi

echo "RetroSync spruce autostart integration uninstalled."

