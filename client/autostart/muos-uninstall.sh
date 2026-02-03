#!/bin/sh
# Uninstall RetroSync background watcher autostart for muOS (MUOS/init).
set -u

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="${2:-$APPDIR/data}"
SIDECAR="$DATA_DIR/autostart_muos.txt"

# Detect MUOS init directory (check both cards)
INIT_DIR=""
if [ -d "/mnt/mmc/MUOS/init" ]; then
  INIT_DIR="/mnt/mmc/MUOS/init"
elif [ -d "/mnt/sdcard/MUOS/init" ]; then
  INIT_DIR="/mnt/sdcard/MUOS/init"
fi

# Remove init script if present
if [ -n "$INIT_DIR" ]; then
  RETRO_INIT="$INIT_DIR/retrosync-init.sh"
  if [ -f "$RETRO_INIT" ]; then
    rm -f "$RETRO_INIT"
    echo "Removed init script: $RETRO_INIT"
  fi
  
  # Remove heartbeat file (created by init script)
  HEARTBEAT="$INIT_DIR/retrosync-heartbeat.txt"
  if [ -f "$HEARTBEAT" ]; then
    rm -f "$HEARTBEAT"
    echo "Removed heartbeat file: $HEARTBEAT"
  fi
  
  # Remove log file (created by init script)
  INIT_LOG="$INIT_DIR/retrosync-init.log"
  if [ -f "$INIT_LOG" ]; then
    rm -f "$INIT_LOG"
    echo "Removed init log: $INIT_LOG"
  fi
fi

# Also check the other card location for cleanup
if [ "$INIT_DIR" != "/mnt/mmc/MUOS/init" ] && [ -d "/mnt/mmc/MUOS/init" ]; then
  if [ -f "/mnt/mmc/MUOS/init/retrosync-init.sh" ]; then
    rm -f "/mnt/mmc/MUOS/init/retrosync-init.sh"
    echo "Removed init script from /mnt/mmc/MUOS/init/"
  fi
  rm -f "/mnt/mmc/MUOS/init/retrosync-heartbeat.txt"
  rm -f "/mnt/mmc/MUOS/init/retrosync-init.log"
fi

if [ "$INIT_DIR" != "/mnt/sdcard/MUOS/init" ] && [ -d "/mnt/sdcard/MUOS/init" ]; then
  if [ -f "/mnt/sdcard/MUOS/init/retrosync-init.sh" ]; then
    rm -f "/mnt/sdcard/MUOS/init/retrosync-init.sh"
    echo "Removed init script from /mnt/sdcard/MUOS/init/"
  fi
  rm -f "/mnt/sdcard/MUOS/init/retrosync-heartbeat.txt"
  rm -f "/mnt/sdcard/MUOS/init/retrosync-init.log"
fi

# Stop watcher process
# Try to find RetroSync directory (check common paths)
RETROSYNC_DIR=""
for path in \
  "/mnt/mmc/Roms/PORTS/RetroSync" \
  "/mnt/mmc/roms/ports/RetroSync" \
  "/mnt/mmc/ports/RetroSync" \
  "/mnt/sdcard/Roms/PORTS/RetroSync" \
  "/mnt/sdcard/roms/ports/RetroSync" \
  "/mnt/sdcard/ports/RetroSync" \
  "$APPDIR"; do
  if [ -d "$path" ] && [ -f "$path/watcher.sh" ]; then
    RETROSYNC_DIR="$path"
    break
  fi
done

if [ -n "$RETROSYNC_DIR" ]; then
  WATCHER="$RETROSYNC_DIR/watcher.sh"
  WATCHER_DATA_DIR="$RETROSYNC_DIR/data"
  PIDFILE="$WATCHER_DATA_DIR/watcher/watcher.pid"
  
  # Stop watcher via PID file
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      echo "Stopped watcher process (PID: $PID)"
    fi
    rm -f "$PIDFILE"
  fi
  
  # Also try pkill as fallback
  if [ -f "$WATCHER" ]; then
    pkill -f "$WATCHER" 2>/dev/null && echo "Stopped watcher via pkill" || true
  fi
fi

# Tell app autostart is disabled (Lua merges into config.json)
echo "0" > "$SIDECAR"

echo "RetroSync muOS autostart integration uninstalled."

