#!/bin/sh
# Install RetroSync background watcher integration into spruceOS networkservices
set -u

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="${2:-$APPDIR/data}"
SIDECAR="$DATA_DIR/autostart_spruce.txt"

mkdir -p "$DATA_DIR"

SPRUCEROOT="/mnt/SDCARD/spruce"
NETWORK_SVC="$SPRUCEROOT/scripts/networkservices.sh"
RETROFUNC_DIR="$SPRUCEROOT/bin/RetroSync"
RETROFUNC="$RETROFUNC_DIR/retrosyncFunctions.sh"

if [ ! -f "$NETWORK_SVC" ]; then
  echo "spruceOS networkservices.sh not found; skipping RetroSync autostart install."
  exit 0
fi

mkdir -p "$RETROFUNC_DIR"

cat > "$RETROFUNC" << 'EOF'
#!/bin/sh
. /mnt/SDCARD/spruce/scripts/helperFunctions.sh

RETROSYNC_DIR="/mnt/SDCARD/Roms/PORTS/RetroSync"
RETROSYNC_WATCHER="$RETROSYNC_DIR/watcher.sh"
RETROSYNC_LOG="/mnt/SDCARD/Saves/spruce/retrosync.log"

start_retrosync_process() {
  read_only_check

  if [ ! -x "$RETROSYNC_WATCHER" ]; then
    log_message "RetroSync: watcher.sh not found or not executable at $RETROSYNC_WATCHER"
    return
  fi

  PIDFILE="$RETROSYNC_DIR/data/watcher/watcher.pid"
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      log_message "RetroSync: watcher already running (pid=$PID)"
      return
    fi
  fi

  if pgrep -f "$RETROSYNC_WATCHER" >/dev/null 2>&1; then
    log_message "RetroSync: watcher already running (pgrep match)"
    return
  fi

  log_message "RetroSync: starting background watcher..."
  mkdir -p "$(dirname "$RETROSYNC_LOG")" 2>/dev/null
  nohup "$RETROSYNC_WATCHER" >>"$RETROSYNC_LOG" 2>&1 &
}

stop_retrosync_process() {
  RETROSYNC_DIR="/mnt/SDCARD/Roms/PORTS/RetroSync"
  PIDFILE="$RETROSYNC_DIR/data/watcher/watcher.pid"

  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$PID" ]; then
      kill "$PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi

  RETROSYNC_WATCHER="$RETROSYNC_DIR/watcher.sh"
  pkill -f "$RETROSYNC_WATCHER" 2>/dev/null || true

  log_message "RetroSync: watcher stopped"
}
EOF

chmod +x "$RETROFUNC"

BACKUP="$NETWORK_SVC.retrosync.bak"
if [ ! -f "$BACKUP" ]; then
  cp "$NETWORK_SVC" "$BACKUP"
fi

# Ensure RetroSync functions are sourced
if ! grep -q 'retrosyncFunctions.sh' "$NETWORK_SVC"; then
  sed -i 's|\. /mnt/SDCARD/spruce/scripts/helperFunctions\.sh|. /mnt/SDCARD/spruce/scripts/helperFunctions.sh\n. /mnt/SDCARD/spruce/bin/RetroSync/retrosyncFunctions.sh|' "$NETWORK_SVC"
fi

# Ensure watcher check block exists
if ! grep -q 'RetroSync watcher check' "$NETWORK_SVC"; then
  sed -i '/# Start Network Services Landing page/i \
 # RetroSync watcher check\n if [ -x /mnt/SDCARD/Roms/PORTS/RetroSync/watcher.sh ]; then\n  if ! pgrep -f "/mnt/SDCARD/Roms/PORTS/RetroSync/watcher.sh" >/dev/null 2>&1; then\n   log_message "Network services: RetroSync watcher not running, starting..."\n   start_retrosync_process\n  fi\n fi\n' "$NETWORK_SVC"
fi

echo "1" > "$SIDECAR"
echo "RetroSync spruce autostart installed."

