#!/bin/sh
# Install RetroSync background watcher autostart for macOS via launchd LaunchAgent.
set -u

# macOS only
if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS only."
  exit 1
fi

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="$APPDIR/data"
MARKER="$DATA_DIR/macos_autostart_installed"

# Ensure APPDIR is absolute
if [ "${APPDIR#/}" = "$APPDIR" ]; then
  APPDIR="$(cd "$APPDIR" && pwd)"
fi

mkdir -p "$DATA_DIR"

# Validate watcher
if [ ! -f "$APPDIR/watcher.sh" ]; then
  echo "ERROR: watcher.sh not found at $APPDIR/watcher.sh"
  exit 1
fi
if [ ! -x "$APPDIR/watcher.sh" ]; then
  echo "ERROR: watcher.sh is not executable at $APPDIR/watcher.sh"
  exit 1
fi

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/com.retrosync.watcher.plist"
LABEL="com.retrosync.watcher"
LOG_PATH="$DATA_DIR/watcher_launchd.log"

mkdir -p "$LAUNCH_AGENTS"

# Generate plist with embedded client path
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>WorkingDirectory</key>
	<string>$APPDIR</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$APPDIR/watcher.sh</string>
	</array>
	<key>StandardOutPath</key>
	<string>$LOG_PATH</string>
	<key>StandardErrorPath</key>
	<string>$LOG_PATH</string>
</dict>
</plist>
EOF

# Unload first if already loaded (so reload picks up changes)
launchctl unload "$PLIST" 2>/dev/null || true

# Load the agent
if launchctl load "$PLIST"; then
  touch "$MARKER"
  echo "RetroSync macOS autostart installed (plist: $PLIST)."
  echo "Watcher will run at login. Add macOS save directories via the app (drag-drop) or dashboard; paths are stored in data/scan_paths.json."
  echo "Check status after boot: launchctl list | grep retrosync   or: ./autostart/macos-status.sh"
else
  echo "ERROR: launchctl load failed for $PLIST"
  exit 1
fi
