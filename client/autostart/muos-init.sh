#!/bin/sh
# RetroSync muOS autostart script
# This script is executed by muOS on boot if "User Init Scripts" is enabled
# 
# IMPORTANT: Update RETROSYNC_DIR below to match your RetroSync installation path

# Create a heartbeat file immediately to prove the script ran (using same pattern as test script)
echo "RetroSync init STARTED at $(date)" > /mnt/mmc/MUOS/init/retrosync-heartbeat.txt 2>/dev/null || echo "RetroSync init STARTED at $(date)" > /mnt/sdcard/MUOS/init/retrosync-heartbeat.txt

# Detect which card this script is on by checking $0's path
SCRIPT_PATH="$0"
INIT_LOG=""
# Use case statement as more portable than grep
case "$SCRIPT_PATH" in
  /mnt/mmc/*)
    INIT_LOG="/mnt/mmc/MUOS/init/retrosync-init.log"
    ;;
  /mnt/sdcard/*)
    INIT_LOG="/mnt/sdcard/MUOS/init/retrosync-init.log"
    ;;
  *)
    # Fallback: try both locations
    if [ -d "/mnt/mmc/MUOS/init" ]; then
      INIT_LOG="/mnt/mmc/MUOS/init/retrosync-init.log"
    else
      INIT_LOG="/mnt/sdcard/MUOS/init/retrosync-init.log"
    fi
    ;;
esac

# Write log IMMEDIATELY - this is the first thing we do
# Use a simple redirect that won't fail even if the directory doesn't exist
{
  echo "=== RetroSync init script started at $(date) ==="
  echo "Script location: $0"
  echo "Detected INIT_LOG: $INIT_LOG"
  echo "Current directory: $(pwd)"
  echo "PATH: $PATH"
  echo "SHELL: $SHELL"
} >> "$INIT_LOG" 2>&1 || {
  # If that failed, try the other location as fallback
  if [ "$INIT_LOG" = "/mnt/mmc/MUOS/init/retrosync-init.log" ]; then
    INIT_LOG="/mnt/sdcard/MUOS/init/retrosync-init.log"
  else
    INIT_LOG="/mnt/mmc/MUOS/init/retrosync-init.log"
  fi
  {
    echo "=== RetroSync init script started at $(date) ==="
    echo "Script location: $0"
    echo "FALLBACK INIT_LOG: $INIT_LOG"
    echo "Current directory: $(pwd)"
  } >> "$INIT_LOG" 2>&1 || true
}

# RetroSync directory path - UPDATE THIS to match your installation
# Based on your actual path, it's at /mnt/sdcard/ports/RetroSync
# If yours is different, change the path below:
RETROSYNC_DIR="/mnt/sdcard/ports/RetroSync"

echo "Using RetroSync directory: $RETROSYNC_DIR" >> "$INIT_LOG" 2>&1

# Verify the directory exists (safety check)
if [ ! -d "$RETROSYNC_DIR" ]; then
  echo "ERROR: RetroSync directory not found at: $RETROSYNC_DIR" >> "$INIT_LOG" 2>&1
  echo "Attempting fallback search..." >> "$INIT_LOG" 2>&1
  # Fallback: try to find it
  for path in \
    "/mnt/mmc/Roms/PORTS/RetroSync" \
    "/mnt/mmc/roms/ports/RetroSync" \
    "/mnt/sdcard/Roms/PORTS/RetroSync" \
    "/mnt/sdcard/roms/ports/RetroSync" \
    "/mnt/sdcard/ports/RetroSync"; do
    if [ -d "$path" ]; then
      RETROSYNC_DIR="$path"
      echo "  FOUND via fallback: $RETROSYNC_DIR" >> "$INIT_LOG" 2>&1
      break
    fi
  done
  if [ ! -d "$RETROSYNC_DIR" ]; then
    echo "ERROR: RetroSync directory not found in any location" >> "$INIT_LOG" 2>&1
    exit 1
  fi
fi

WATCHER="$RETROSYNC_DIR/watcher.sh"
DATA_DIR="$RETROSYNC_DIR/data"
WATCHER_LOG="$DATA_DIR/muos_autostart.log"

echo "RetroSync directory: $RETROSYNC_DIR" >> "$INIT_LOG" 2>&1
echo "Watcher path: $WATCHER" >> "$INIT_LOG" 2>&1

mkdir -p "$DATA_DIR" 2>/dev/null
echo "Created data dir: $DATA_DIR" >> "$INIT_LOG" 2>&1

if [ ! -f "$WATCHER" ]; then
  echo "ERROR: watcher.sh file not found at $WATCHER" >> "$INIT_LOG" 2>&1
  exit 1
fi

if [ ! -x "$WATCHER" ]; then
  echo "ERROR: watcher.sh exists but is NOT executable at $WATCHER" >> "$INIT_LOG" 2>&1
  ls -l "$WATCHER" >> "$INIT_LOG" 2>&1
  exit 1
fi

echo "Watcher is executable, checking if already running..." >> "$INIT_LOG" 2>&1

PIDFILE="$DATA_DIR/watcher.pid"
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null)
  echo "  Found pidfile with PID: $PID" >> "$INIT_LOG" 2>&1
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "  Watcher already running (pid=$PID via pidfile)" >> "$INIT_LOG" 2>&1
    exit 0
  else
    echo "  PID $PID from pidfile is not running, continuing..." >> "$INIT_LOG" 2>&1
  fi
fi

if pgrep -f "$WATCHER" >/dev/null 2>&1; then
  echo "  Watcher already running (pgrep match)" >> "$INIT_LOG" 2>&1
  exit 0
fi

echo "Starting watcher..." >> "$INIT_LOG" 2>&1
nohup "$WATCHER" >>"$WATCHER_LOG" 2>&1 &
WATCHER_PID=$!
echo "  Watcher launched with PID: $WATCHER_PID" >> "$INIT_LOG" 2>&1
sleep 1
if kill -0 "$WATCHER_PID" 2>/dev/null; then
  echo "  Watcher is running (verified)" >> "$INIT_LOG" 2>&1
else
  echo "  WARNING: Watcher PID $WATCHER_PID died immediately" >> "$INIT_LOG" 2>&1
fi
echo "=== RetroSync init script completed at $(date) ===" >> "$INIT_LOG" 2>&1

# Update heartbeat to show completion
echo "RetroSync init COMPLETED at $(date)" >> "/mnt/mmc/MUOS/init/retrosync-heartbeat.txt" 2>/dev/null || \
echo "RetroSync init COMPLETED at $(date)" >> "/mnt/sdcard/MUOS/init/retrosync-heartbeat.txt" 2>/dev/null || true
