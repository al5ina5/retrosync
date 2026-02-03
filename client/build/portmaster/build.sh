#!/bin/bash
# build-miyoo.sh
# Builds PortMaster package for RetroSync
#
# Usage: ./build-miyoo.sh
# Output: dist/portmaster/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CLIENT_DIR="$PROJECT_ROOT/client"
GAME_NAME="RetroSync"
BUILD_DIR="$CLIENT_DIR/dist/portmaster"

cd "$CLIENT_DIR"

echo "=== Building PortMaster Package for $GAME_NAME ==="
echo "Project root: $PROJECT_ROOT"
echo "Output: $BUILD_DIR"
echo ""

# 1. Clean and create build structure
echo "[1/5] Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$GAME_NAME"

# Copy assets folder to dist
echo "[1.5/5] Copying assets folder..."
if [ -d "$CLIENT_DIR/assets" ]; then
    cp -r "$CLIENT_DIR/assets" "$BUILD_DIR/$GAME_NAME/assets"
    echo "  ✓ Assets copied"
else
    echo "  ⚠ Warning: assets folder not found"
fi

# 2. Package the .love file
echo "[2/5] Creating $GAME_NAME.love..."
cd "$CLIENT_DIR"
zip -9 -r "$BUILD_DIR/$GAME_NAME/$GAME_NAME.love" . \
    -x "*.DS_Store" \
    -x "build/*" \
    -x "dist/*" \
    -x ".git/*" \
    -x ".gitignore" > /dev/null 2>&1

# 3. Create watcher daemon + helper scripts
echo "[3/6] Creating watcher scripts..."

# watcher.sh is now tracked in the repo (client/watcher.sh) so we can
# version-control fixes and logging. Copy it into the PortMaster build.
if [ -f "$CLIENT_DIR/watcher.sh" ]; then
  cp "$CLIENT_DIR/watcher.sh" "$BUILD_DIR/$GAME_NAME/watcher.sh"
else
  echo "ERROR: client/watcher.sh not found; watcher will be missing from build." >&2
  exit 1
fi

chmod +x "$BUILD_DIR/$GAME_NAME/watcher.sh"

# Autostart scripts (copied from source autostart folder)
mkdir -p "$BUILD_DIR/$GAME_NAME/autostart"
for script in "$CLIENT_DIR"/autostart/*.sh; do
  if [ -f "$script" ]; then
    base="$(basename "$script")"
    cp "$script" "$BUILD_DIR/$GAME_NAME/autostart/$base"
    chmod +x "$BUILD_DIR/$GAME_NAME/autostart/$base"
  fi
done

# Seed config.json in LÖVE save dir (shared script; same structure on all builds).
source "$SCRIPT_DIR/../shared/vars.sh"
LOVE_DATA_SUBDIR="$RETROSYNC_LOVE_DATA_SUBDIR"
bash "$SCRIPT_DIR/../shared/write_config_json.sh" "$BUILD_DIR/$GAME_NAME/$LOVE_DATA_SUBDIR" "${RETROSYNC_SERVER_URL:-}"
if [ -n "${RETROSYNC_SERVER_URL:-}" ]; then
  echo "  ✓ Baked server URL into config.json for release"
else
  echo "  ✓ Seeded default config.json"
fi

# 4. Create the Launcher (.sh)
echo "[4/6] Creating launcher script..."
cat > "$BUILD_DIR/$GAME_NAME.sh" << 'LAUNCHER_EOF'
#!/bin/bash
# PortMaster Launcher for RetroSync

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt

get_controls
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

# Dynamic path resolution - remove trailing slashes, handle leading slash
GAMEDIR="${directory%/}/RetroSync"
# Ensure path starts with /
[[ "$GAMEDIR" != /* ]] && GAMEDIR="/$GAMEDIR"

# If not found in root, check in /ports/ subfolder
if [ ! -d "$GAMEDIR" ]; then
    GAMEDIR="${directory%/}/ports/RetroSync"
    [[ "$GAMEDIR" != /* ]] && GAMEDIR="/$GAMEDIR"
fi

cd "$GAMEDIR"

# LÖVE data dir = getSaveDirectory() when XDG_DATA_HOME=GAMEDIR/saves (identity "retrosync" from conf.lua).
export XDG_DATA_HOME="$GAMEDIR/saves"
export XDG_CONFIG_HOME="$GAMEDIR/saves"
DATA_DIR="$GAMEDIR/saves/love/retrosync"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$DATA_DIR"

# Redirect all output to log.txt for debugging
exec > >(tee "$GAMEDIR/log.txt") 2>&1
echo "--- Starting RetroSync ---"
echo "Date: $(date)"
echo "GAMEDIR: $GAMEDIR"
echo "DATA_DIR: $DATA_DIR"
echo "Device: $DEVICE_NAME ($DEVICE_ARCH)"

# Auto-install spruceOS autostart integration (one-time, silent if fails)
SPRUCENET="/mnt/SDCARD/spruce/scripts/networkservices.sh"
SPRUCER_INSTALLER="$GAMEDIR/autostart/spruce-install.sh"
if [ -f "$SPRUCENET" ] && [ -x "$SPRUCER_INSTALLER" ]; then
    SPRUCE_ALREADY=false
    if [ -f "$DATA_DIR/config.json" ] && command -v jq >/dev/null 2>&1; then
        jq -e '.autostart == "spruceos"' "$DATA_DIR/config.json" >/dev/null 2>&1 && SPRUCE_ALREADY=true
    fi
    if [ "$SPRUCE_ALREADY" = false ]; then
        echo "Detected spruceOS, installing RetroSync autostart integration..."
        "$SPRUCER_INSTALLER" "$GAMEDIR" "$DATA_DIR" >/dev/null 2>&1 || true
        echo "RetroSync autostart install attempted for spruceOS (see log if needed)"
    fi
fi

# Auto-install muOS autostart integration via MUOS/init (one-time, silent if fails)
MUOS_INSTALLER="$GAMEDIR/autostart/muos-install.sh"
if [ -x "$MUOS_INSTALLER" ]; then
    MUOS_ALREADY=false
    if [ -f "$DATA_DIR/config.json" ] && command -v jq >/dev/null 2>&1; then
        jq -e '.autostart == "muos"' "$DATA_DIR/config.json" >/dev/null 2>&1 && MUOS_ALREADY=true
    fi
    if [ "$MUOS_ALREADY" = false ]; then
        if [ -d "/mnt/mmc/MUOS/init" ] || [ -d "/mnt/sdcard/MUOS/init" ]; then
            echo "Detected muOS, installing RetroSync muOS init integration..."
            "$MUOS_INSTALLER" "$GAMEDIR" "$DATA_DIR" >> "$GAMEDIR/log.txt" 2>&1 || true
            echo "RetroSync muOS autostart install attempted (remember to enable User Init Scripts in muOS settings; check log.txt for details)"
        else
            echo "muOS detected but MUOS/init directory not found on either card"
        fi
    fi
else
    echo "muOS installer not found or not executable at $MUOS_INSTALLER"
fi

# Start background watcher daemon (uses same DATA_DIR as LÖVE app: config, logs, watcher state)
WATCHER="$GAMEDIR/watcher.sh"
WATCHER_PIDFILE="$DATA_DIR/watcher/watcher.pid"
if [ -x "$WATCHER" ]; then
    if [ -f "$WATCHER_PIDFILE" ] && kill -0 "$(cat "$WATCHER_PIDFILE" 2>/dev/null)" 2>/dev/null; then
        echo "Watcher already running (pid $(cat "$WATCHER_PIDFILE" 2>/dev/null))"
    else
        echo "Starting watcher daemon..."
        nohup setsid "$WATCHER" "$GAMEDIR" "$DATA_DIR" >/dev/null 2>&1 &
        sleep 0.1
        if [ -f "$WATCHER_PIDFILE" ]; then
            echo "Watcher started (pid $(cat "$WATCHER_PIDFILE" 2>/dev/null))"
        else
            echo "Watcher start attempted (no pidfile yet)"
        fi
    fi
else
    echo "Watcher not found/executable, skipping"
fi

# Search for LÖVE binary
LOVE_BIN=""
# 1. Check PortMaster runtimes first (highest quality)
for ver in "11.5" "11.4"; do
    R_PATH="$controlfolder/runtimes/love_$ver/love.$DEVICE_ARCH"
    if [ -f "$R_PATH" ]; then
        LOVE_BIN="$R_PATH"
        export LD_LIBRARY_PATH="$(dirname "$R_PATH")/libs.$DEVICE_ARCH:$LD_LIBRARY_PATH"
        break
    fi
done

# 2. Check system paths fallback
if [ -z "$LOVE_BIN" ]; then
    for path in "/usr/bin/love" "/usr/local/bin/love" "/opt/love/bin/love"; do
        if [ -f "$path" ]; then
            LOVE_BIN="$path"
            break
        fi
    done
fi

if [ -z "$LOVE_BIN" ]; then
    echo "ERROR: LÖVE binary not found in runtimes or system paths!"
    exit 1
fi

echo "Using LÖVE binary: $LOVE_BIN"

# We use the basename of LOVE_BIN for gptokeyb to watch
LOVE_NAME=$(basename "$LOVE_BIN")

$GPTOKEYB "$LOVE_NAME" -c "$GAMEDIR/RetroSync.gptk" &
pm_platform_helper "$LOVE_BIN"
"$LOVE_BIN" "$GAMEDIR/RetroSync.love"

# Cleanup after exit
killall gptokeyb
pm_finish
LAUNCHER_EOF

chmod +x "$BUILD_DIR/$GAME_NAME.sh"

# 5. Create a top-level uninstaller adjacent to the launcher
echo "[5/6] Creating top-level uninstaller..."
cat > "$BUILD_DIR/${GAME_NAME}Uninstaller.sh" << 'TOP_UNINSTALL_EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/RetroSync"

echo "--- RetroSync Uninstall (autostart integrations) ---"

if [ -d "$APP_DIR" ] && [ -x "$APP_DIR/autostart/spruce-uninstall.sh" ]; then
  "$APP_DIR/autostart/spruce-uninstall.sh" "$APP_DIR" || true
  echo "RetroSync spruce autostart integration removed (if it was installed)."
fi

if [ -d "$APP_DIR" ] && [ -x "$APP_DIR/autostart/muos-uninstall.sh" ]; then
  "$APP_DIR/autostart/muos-uninstall.sh" "$APP_DIR" || true
  echo "RetroSync muOS autostart integration removed (if it was installed)."
else
  echo "RetroSync app folder or autostart uninstallers not found; nothing to do."
fi
TOP_UNINSTALL_EOF

chmod +x "$BUILD_DIR/${GAME_NAME}Uninstaller.sh"

# 6. Create the Controller Mapping (.gptk)
echo "[6/6] Creating controller mapping..."
cat > "$BUILD_DIR/$GAME_NAME/$GAME_NAME.gptk" << 'EOF'
back = escape
start = enter

up = up
down = down
left = left
right = right

left_analog_up = up
left_analog_down = down
left_analog_left = left
left_analog_right = right

a = x
b = z
x = space
y = c

l1 = c
r1 = x
EOF

# 7. Create PortMaster metadata (port.json)
echo "[7/7] Creating port.json..."
cat > "$BUILD_DIR/$GAME_NAME/port.json" << EOF
{
    "version": 1,
    "name": "$GAME_NAME",
    "items": ["$GAME_NAME.sh"],
    "items_opt": [],
    "attr": {
        "title": "RetroSync",
        "desc": "Cloud sync service for retro gaming save files. Pair your device and upload save files to sync across devices.",
        "inst": "Enter pairing code from web dashboard. Press A to upload saves.",
        "genres": ["utility", "tool"],
        "porter": "RetroSync Team",
        "runtime": "love-11.4"
    }
}
EOF

echo ""
echo "=== BUILD COMPLETE ==="
echo ""
echo "Output files:"
echo "  $BUILD_DIR/$GAME_NAME.sh"
echo "  $BUILD_DIR/${GAME_NAME}Uninstaller.sh"
echo "  $BUILD_DIR/$GAME_NAME/"
echo "    - $GAME_NAME.love"
echo "    - $GAME_NAME.gptk"
echo "    - watcher.sh"
echo "    - autostart/spruce-install.sh"
echo "    - autostart/spruce-uninstall.sh"
echo "    - autostart/muos-install.sh"
echo "    - autostart/muos-uninstall.sh"
echo "    - saves/love/retrosync/config.json (LÖVE data dir = getSaveDirectory())"
echo "    - port.json"
echo ""
echo "To deploy, run: ./deploy.sh"
