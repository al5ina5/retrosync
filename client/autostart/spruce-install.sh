#!/bin/sh
# Install RetroSync background watcher integration into spruceOS networkservices
set -u

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
# Must match LÖVE getSaveDirectory(): saves/love/retrosync when XDG_DATA_HOME=GAMEDIR/saves (identity from conf.lua).
DATA_DIR="${2:-$APPDIR/saves/love/retrosync}"
CONFIG_JSON="$DATA_DIR/config.json"

mkdir -p "$DATA_DIR"

# Ensure APPDIR and DATA_DIR are absolute paths
if [ "${APPDIR#/}" = "$APPDIR" ]; then
  APPDIR="$(cd "$APPDIR" && pwd)"
fi
if [ "${DATA_DIR#/}" = "$DATA_DIR" ]; then
  DATA_DIR="$(cd "$DATA_DIR" 2>/dev/null && pwd)" || DATA_DIR="$APPDIR/saves/love/retrosync"
fi

SPRUCEROOT="/mnt/SDCARD/spruce"
NETWORK_SVC="$SPRUCEROOT/scripts/networkservices.sh"
RETROFUNC_DIR="$SPRUCEROOT/bin/RetroSync"
RETROFUNC="$RETROFUNC_DIR/retrosyncFunctions.sh"

if [ ! -f "$NETWORK_SVC" ]; then
  echo "spruceOS networkservices.sh not found; skipping RetroSync autostart install."
  exit 0
fi

mkdir -p "$RETROFUNC_DIR"

cat > "$RETROFUNC" << EOF
#!/bin/sh
. /mnt/SDCARD/spruce/scripts/helperFunctions.sh

RETROSYNC_DIR="${APPDIR}"
RETROSYNC_DATA="${DATA_DIR}"
RETROSYNC_WATCHER="\$RETROSYNC_DIR/watcher.sh"
RETROSYNC_LOG="\$RETROSYNC_DATA/logs/watcher.log"

start_retrosync_process() {
  read_only_check

  if [ ! -x "\$RETROSYNC_WATCHER" ]; then
    log_message "RetroSync: watcher.sh not found or not executable at \$RETROSYNC_WATCHER"
    return
  fi

  PIDFILE="\$RETROSYNC_DATA/watcher/watcher.pid"
  if [ -f "\$PIDFILE" ]; then
    PID=\$(cat "\$PIDFILE" 2>/dev/null)
    if [ -n "\$PID" ] && kill -0 "\$PID" 2>/dev/null; then
      log_message "RetroSync: watcher already running (pid=\$PID)"
      return
    fi
  fi

  if pgrep -f "\$RETROSYNC_WATCHER" >/dev/null 2>&1; then
    log_message "RetroSync: watcher already running (pgrep match)"
    return
  fi

  log_message "RetroSync: starting background watcher..."
  mkdir -p "\$(dirname "\$RETROSYNC_LOG")" 2>/dev/null
  nohup "\$RETROSYNC_WATCHER" "\$RETROSYNC_DIR" "\$RETROSYNC_DATA" >>"\$RETROSYNC_LOG" 2>&1 &
}

stop_retrosync_process() {
  PIDFILE="\$RETROSYNC_DATA/watcher/watcher.pid"

  if [ -f "\$PIDFILE" ]; then
    PID=\$(cat "\$PIDFILE" 2>/dev/null)
    if [ -n "\$PID" ]; then
      kill "\$PID" 2>/dev/null || true
    fi
    rm -f "\$PIDFILE"
  fi

  RETROSYNC_WATCHER="\$RETROSYNC_DIR/watcher.sh"
  pkill -f "\$RETROSYNC_WATCHER" 2>/dev/null || true

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

# Mark autostart in config.json (single source of truth).
# If jq is missing, write a sidecar to avoid clobbering an existing config.
if command -v jq >/dev/null 2>&1; then
  if [ -f "$CONFIG_JSON" ]; then
    jq '.autostart = "spruceos"' "$CONFIG_JSON" > "$CONFIG_JSON.tmp" && mv "$CONFIG_JSON.tmp" "$CONFIG_JSON"
  else
    printf '%s\n' '{"autostart":"spruceos"}' > "$CONFIG_JSON"
  fi
else
  if [ -f "$CONFIG_JSON" ]; then
    printf '%s\n' "1" > "$DATA_DIR/autostart_spruce.txt"
  else
    printf '%s\n' '{"autostart":"spruceos"}' > "$CONFIG_JSON"
  fi
fi
echo "RetroSync spruce autostart installed."
