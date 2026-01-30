#!/bin/sh
# Uninstall RetroSync background watcher autostart for macOS (launchd LaunchAgent).
set -u

# macOS only
if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS only."
  exit 1
fi

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="$APPDIR/data"
MARKER="$DATA_DIR/macos_autostart_installed"
PLIST="$HOME/Library/LaunchAgents/com.retrosync.watcher.plist"
PIDFILE="$DATA_DIR/watcher.pid"
WATCHER="$APPDIR/watcher.sh"

# Unload the LaunchAgent (ignore errors if not loaded)
launchctl unload "$PLIST" 2>/dev/null || true

# Remove plist
if [ -f "$PLIST" ]; then
  rm -f "$PLIST"
  echo "Removed LaunchAgent plist: $PLIST"
fi

# Stop watcher via PID file
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    echo "Stopped watcher process (PID: $PID)"
  fi
  rm -f "$PIDFILE"
fi

# Fallback: pkill by watcher path
if [ -f "$WATCHER" ]; then
  pkill -f "$WATCHER" 2>/dev/null && echo "Stopped watcher via pkill" || true
fi

# Remove install marker
if [ -f "$MARKER" ]; then
  rm -f "$MARKER"
  echo "Removed install marker: $MARKER"
fi

echo "RetroSync macOS autostart uninstalled."
