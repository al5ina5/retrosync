#!/bin/sh
# Install RetroSync background watcher autostart for muOS via MUOS/init user init scripts.
set -u

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="$APPDIR/data"
MARKER="$DATA_DIR/muos_autostart_installed"

# Log to RetroSync log.txt so we can see what's happening
INSTALL_LOG="$APPDIR/log.txt"

echo "[muos-install] Starting muOS autostart installer..." >> "$INSTALL_LOG" 2>&1
echo "[muos-install] APPDIR: $APPDIR" >> "$INSTALL_LOG" 2>&1

mkdir -p "$DATA_DIR"

# Detect MUOS init directory (primary SD: /mnt/mmc, secondary SD: /mnt/sdcard)
INIT_DIR=""
echo "[muos-install] Checking for MUOS/init directories..." >> "$INSTALL_LOG" 2>&1
if [ -d "/mnt/mmc/MUOS/init" ]; then
  INIT_DIR="/mnt/mmc/MUOS/init"
  echo "[muos-install] Found: /mnt/mmc/MUOS/init" >> "$INSTALL_LOG" 2>&1
elif [ -d "/mnt/sdcard/MUOS/init" ]; then
  INIT_DIR="/mnt/sdcard/MUOS/init"
  echo "[muos-install] Found: /mnt/sdcard/MUOS/init" >> "$INSTALL_LOG" 2>&1
else
  echo "[muos-install] ERROR: MUOS/init directory not found in /mnt/mmc or /mnt/sdcard" >> "$INSTALL_LOG" 2>&1
fi

if [ -z "$INIT_DIR" ]; then
  echo "[muos-install] muOS MUOS/init directory not found; skipping RetroSync muOS autostart install."
  echo "[muos-install] muOS MUOS/init directory not found; skipping RetroSync muOS autostart install." >> "$INSTALL_LOG" 2>&1
  exit 0
fi

RETRO_INIT="$INIT_DIR/retrosync-init.sh"
echo "[muos-install] Will create init script at: $RETRO_INIT" >> "$INSTALL_LOG" 2>&1
echo "[muos-install] RetroSync directory: $APPDIR" >> "$INSTALL_LOG" 2>&1

# Ensure APPDIR is an absolute path
if [ "${APPDIR#/}" = "$APPDIR" ]; then
  # Not absolute, make it absolute
  APPDIR="$(cd "$APPDIR" && pwd)"
  echo "[muos-install] Converted to absolute path: $APPDIR" >> "$INSTALL_LOG" 2>&1
fi

# Embed the RetroSync directory path directly into the script
# This way the init script knows exactly where RetroSync is without searching
# Using EOF (not 'EOF') so ${APPDIR} gets expanded to the actual path
# Note: Variables that should be literal in the generated script are escaped with \
cat > "$RETRO_INIT" << EOF
#!/bin/sh
# RetroSync muOS autostart script
# This script is executed by muOS on boot if "User Init Scripts" is enabled

# Create a heartbeat file immediately to prove the script ran (using same pattern as test script)
echo "RetroSync init STARTED at \$(date)" > /mnt/mmc/MUOS/init/retrosync-heartbeat.txt 2>/dev/null || echo "RetroSync init STARTED at \$(date)" > /mnt/sdcard/MUOS/init/retrosync-heartbeat.txt

# Detect which card this script is on by checking \$0's path
SCRIPT_PATH="\$0"
INIT_LOG=""
# Use case statement as more portable than grep
case "\$SCRIPT_PATH" in
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
  echo "=== RetroSync init script started at \$(date) ==="
  echo "Script location: \$0"
  echo "Detected INIT_LOG: \$INIT_LOG"
  echo "Current directory: \$(pwd)"
  echo "PATH: \$PATH"
  echo "SHELL: \$SHELL"
} >> "\$INIT_LOG" 2>&1 || {
  # If that failed, try the other location as fallback
  if [ "\$INIT_LOG" = "/mnt/mmc/MUOS/init/retrosync-init.log" ]; then
    INIT_LOG="/mnt/sdcard/MUOS/init/retrosync-init.log"
  else
    INIT_LOG="/mnt/mmc/MUOS/init/retrosync-init.log"
  fi
  {
    echo "=== RetroSync init script started at \$(date) ==="
    echo "Script location: \$0"
    echo "FALLBACK INIT_LOG: \$INIT_LOG"
    echo "Current directory: \$(pwd)"
  } >> "\$INIT_LOG" 2>&1 || true
}

# RetroSync directory path - embedded at install time with the actual RetroSync directory path
RETROSYNC_DIR="${APPDIR}"
echo "Using RetroSync directory: \$RETROSYNC_DIR" >> "\$INIT_LOG" 2>&1

# Verify the directory exists (safety check)
if [ ! -d "\$RETROSYNC_DIR" ]; then
  echo "ERROR: RetroSync directory not found at: \$RETROSYNC_DIR" >> "\$INIT_LOG" 2>&1
  echo "Attempting fallback search..." >> "\$INIT_LOG" 2>&1
  # Fallback: try to find it
  for path in \
    "/mnt/mmc/Roms/PORTS/RetroSync" \
    "/mnt/mmc/roms/ports/RetroSync" \
    "/mnt/mmc/ports/RetroSync" \
    "/mnt/sdcard/Roms/PORTS/RetroSync" \
    "/mnt/sdcard/roms/ports/RetroSync" \
    "/mnt/sdcard/ports/RetroSync"; do
    if [ -d "\$path" ]; then
      RETROSYNC_DIR="\$path"
      echo "  FOUND via fallback: \$RETROSYNC_DIR" >> "\$INIT_LOG" 2>&1
      break
    fi
  done
  if [ ! -d "\$RETROSYNC_DIR" ]; then
    echo "ERROR: RetroSync directory not found in any location" >> "\$INIT_LOG" 2>&1
    exit 1
  fi
fi

WATCHER="\$RETROSYNC_DIR/watcher.sh"
DATA_DIR="\$RETROSYNC_DIR/data"
WATCHER_LOG="\$DATA_DIR/muos_autostart.log"

echo "RetroSync directory: \$RETROSYNC_DIR" >> "\$INIT_LOG" 2>&1
echo "Watcher path: \$WATCHER" >> "\$INIT_LOG" 2>&1

mkdir -p "\$DATA_DIR" 2>/dev/null
echo "Created data dir: \$DATA_DIR" >> "\$INIT_LOG" 2>&1

if [ ! -f "\$WATCHER" ]; then
  echo "ERROR: watcher.sh file not found at \$WATCHER" >> "\$INIT_LOG" 2>&1
  exit 1
fi

if [ ! -x "\$WATCHER" ]; then
  echo "ERROR: watcher.sh exists but is NOT executable at \$WATCHER" >> "\$INIT_LOG" 2>&1
  ls -l "\$WATCHER" >> "\$INIT_LOG" 2>&1
  exit 1
fi

echo "Watcher is executable, checking if already running..." >> "\$INIT_LOG" 2>&1

PIDFILE="\$DATA_DIR/watcher.pid"
if [ -f "\$PIDFILE" ]; then
  PID=\$(cat "\$PIDFILE" 2>/dev/null)
  echo "  Found pidfile with PID: \$PID" >> "\$INIT_LOG" 2>&1
  if [ -n "\$PID" ] && kill -0 "\$PID" 2>/dev/null; then
    echo "  Watcher already running (pid=\$PID via pidfile)" >> "\$INIT_LOG" 2>&1
    exit 0
  else
    echo "  PID \$PID from pidfile is not running, continuing..." >> "\$INIT_LOG" 2>&1
  fi
fi

if pgrep -f "\$WATCHER" >/dev/null 2>&1; then
  echo "  Watcher already running (pgrep match)" >> "\$INIT_LOG" 2>&1
  exit 0
fi

echo "Starting watcher..." >> "\$INIT_LOG" 2>&1
nohup "\$WATCHER" >>"\$WATCHER_LOG" 2>&1 &
WATCHER_PID=\$!
echo "  Watcher launched with PID: \$WATCHER_PID" >> "\$INIT_LOG" 2>&1
sleep 1
if kill -0 "\$WATCHER_PID" 2>/dev/null; then
  echo "  Watcher is running (verified)" >> "\$INIT_LOG" 2>&1
else
  echo "  WARNING: Watcher PID \$WATCHER_PID died immediately" >> "\$INIT_LOG" 2>&1
fi
echo "=== RetroSync init script completed at \$(date) ===" >> "\$INIT_LOG" 2>&1

# Update heartbeat to show completion
echo "RetroSync init COMPLETED at \$(date)" >> "/mnt/mmc/MUOS/init/retrosync-heartbeat.txt" 2>/dev/null || \
echo "RetroSync init COMPLETED at \$(date)" >> "/mnt/sdcard/MUOS/init/retrosync-heartbeat.txt" 2>/dev/null || true
EOF

# Verify the script was written correctly (not blank)
if [ ! -s "$RETRO_INIT" ]; then
  echo "[muos-install] ERROR: Generated script is empty or blank!" >> "$INSTALL_LOG" 2>&1
  echo "[muos-install] APPDIR was: $APPDIR" >> "$INSTALL_LOG" 2>&1
  rm -f "$RETRO_INIT"
  exit 1
fi

# Verify the embedded path is in the script
if ! grep -q "RETROSYNC_DIR=" "$RETRO_INIT"; then
  echo "[muos-install] ERROR: Generated script missing RETROSYNC_DIR variable!" >> "$INSTALL_LOG" 2>&1
  rm -f "$RETRO_INIT"
  exit 1
fi

echo "[muos-install] Script generated successfully, size: $(wc -c < "$RETRO_INIT" 2>/dev/null || echo 0) bytes" >> "$INSTALL_LOG" 2>&1

# Ensure script is executable (critical for muOS to run it)
echo "[muos-install] Making script executable..." >> "$INSTALL_LOG" 2>&1
if chmod +x "$RETRO_INIT" 2>/dev/null; then
  echo "[muos-install] Init script made executable: $RETRO_INIT" >> "$INSTALL_LOG" 2>&1
else
  echo "[muos-install] WARNING: Failed to make $RETRO_INIT executable (chmod may have failed)" >> "$INSTALL_LOG" 2>&1
  # Try alternative: ensure parent dir is writable and retry
  chmod +x "$RETRO_INIT" >> "$INSTALL_LOG" 2>&1 || echo "[muos-install] ERROR: chmod failed even after retry" >> "$INSTALL_LOG" 2>&1
fi

# Verify it's actually executable
if [ -x "$RETRO_INIT" ]; then
  echo "[muos-install] Verified: $RETRO_INIT is executable" >> "$INSTALL_LOG" 2>&1
else
  echo "[muos-install] ERROR: $RETRO_INIT exists but is NOT executable - muOS will not run it!" >> "$INSTALL_LOG" 2>&1
fi

touch "$MARKER"
echo "[muos-install] Marker created: $MARKER" >> "$INSTALL_LOG" 2>&1
echo "[muos-install] RetroSync muOS autostart installed (script: $RETRO_INIT)." >> "$INSTALL_LOG" 2>&1
echo "RetroSync muOS autostart installed (script: $RETRO_INIT)."

