#!/bin/sh
# Install RetroSync background watcher autostart for macOS via launchd LaunchAgent.
set -u

# macOS only
if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS only."
  exit 1
fi

APPDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="${2:-$APPDIR/data}"
CONFIG_JSON="$DATA_DIR/config.json"

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

mkdir -p "$LAUNCH_AGENTS"

# Ensure DATA_DIR is absolute so watcher uses same dir as LÖVE app (config/logs)
if [ "${DATA_DIR#/}" = "$DATA_DIR" ]; then
  DATA_DIR="$(cd "$DATA_DIR" 2>/dev/null && pwd)" || DATA_DIR="$APPDIR/data"
fi

# Generate plist: pass APPDIR and DATA_DIR so watcher uses LÖVE data dir and writes to data/watcher/
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
		<string>$APPDIR</string>
		<string>$DATA_DIR</string>
	</array>
</dict>
</plist>
EOF

# Unload first if already loaded (so reload picks up changes)
launchctl unload "$PLIST" 2>/dev/null || true

# Load the agent
if launchctl load "$PLIST"; then
  # Update config.json so the app shows autostart enabled. Prefer jq; fall back to Ruby (built into macOS).
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$CONFIG_JSON" ]; then
      jq '.autostart = "macos"' "$CONFIG_JSON" > "$CONFIG_JSON.tmp" && mv "$CONFIG_JSON.tmp" "$CONFIG_JSON"
    else
      printf '%s\n' '{"autostart":"macos"}' > "$CONFIG_JSON"
    fi
  else
    if command -v ruby >/dev/null 2>&1; then
      if [ -f "$CONFIG_JSON" ]; then
        ruby -rjson -e "
          p = ARGV[0]
          d = File.exist?(p) ? JSON.parse(File.read(p)) : {}
          d['autostart'] = 'macos'
          File.write(p, JSON.pretty_generate(d))
        " "$CONFIG_JSON" 2>/dev/null || true
      else
        printf '%s\n' '{"autostart":"macos"}' > "$CONFIG_JSON"
      fi
    fi
  fi
  echo "RetroSync macOS autostart installed (plist: $PLIST)."
  echo "Watcher will run at login. Config and paths: $DATA_DIR/config.json, $DATA_DIR/scan_paths.json."
  echo "Watcher runs at login. Check: launchctl list | grep retrosync"
else
  echo "ERROR: launchctl load failed for $PLIST"
  exit 1
fi
