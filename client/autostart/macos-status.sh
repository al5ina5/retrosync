#!/bin/sh
# Check if RetroSync watcher autostart is installed and if the watcher process is running.
set -u

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS only."
  exit 1
fi

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="$APPDIR/data"
PIDFILE="$DATA_DIR/watcher.pid"
PLIST="$HOME/Library/LaunchAgents/com.retrosync.watcher.plist"
LABEL="com.retrosync.watcher"

echo "=== RetroSync macOS autostart status ==="
echo ""

# LaunchAgent loaded?
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  echo "LaunchAgent: loaded (runs at login)"
  launchctl list | grep "$LABEL"
else
  echo "LaunchAgent: not loaded (run ./autostart/macos-install.sh to install)"
fi
echo ""

# Watcher process alive?
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "Watcher process: running (PID $PID)"
    ps -p "$PID" -o pid,etime,command 2>/dev/null || true
  else
    echo "Watcher process: not running (stale PID file)"
  fi
else
  echo "Watcher process: no PID file (not running or not started by autostart)"
fi
echo ""

echo "Logs: $DATA_DIR/watcher.log  (and $DATA_DIR/watcher_launchd.log for launchd)"
