#!/bin/bash
# deploy.sh
# Builds and deploys RetroSync to PortMaster devices via SSH
#
# Usage: ./deploy.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CLIENT_DIR="$PROJECT_ROOT/client"
GAME_NAME="RetroSync"
DIST_DIR="$CLIENT_DIR/dist/portmaster"

cd "$CLIENT_DIR"

echo "=== Building $GAME_NAME ==="
"$SCRIPT_DIR/build.sh"

echo ""
echo "=== Deploying to SpruceOS (10.0.0.93) ==="

# --- SpruceOS Configuration ---
SPRUCE_IP="10.0.0.93"
SPRUCE_USER="spruce"
SPRUCE_PASS="happygaming"
SPRUCE_PATH="/mnt/sdcard/Roms/PORTS"

# Test SSH connection first
echo "Testing connection..."
if ! sshpass -p "$SPRUCE_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SPRUCE_USER@$SPRUCE_IP" "echo OK" 2>/dev/null; then
    echo "ERROR: Cannot connect to $SPRUCE_IP"
    echo "Make sure device is on and SSH is enabled"
    exit 1
fi
echo "Connected!"

# Clean old files first, but preserve saves folder (LÖVE data = getSaveDirectory())
echo "Cleaning old files (preserving saves folder)..."
sshpass -p "$SPRUCE_PASS" ssh -o StrictHostKeyChecking=no "$SPRUCE_USER@$SPRUCE_IP" \
    "if [ -d '$SPRUCE_PATH/$GAME_NAME' ]; then \
        if [ -d '$SPRUCE_PATH/$GAME_NAME/saves' ]; then \
            mkdir -p /tmp/retrosync_saves_backup && \
            cp -r '$SPRUCE_PATH/$GAME_NAME/saves' /tmp/retrosync_saves_backup/ && \
            rm -rf '$SPRUCE_PATH/$GAME_NAME' '$SPRUCE_PATH/$GAME_NAME.sh' '$SPRUCE_PATH/${GAME_NAME}Uninstaller.sh' && \
            mkdir -p '$SPRUCE_PATH/$GAME_NAME' && \
            mv /tmp/retrosync_saves_backup/saves '$SPRUCE_PATH/$GAME_NAME/' && \
            rm -rf /tmp/retrosync_saves_backup; \
        else \
            rm -rf '$SPRUCE_PATH/$GAME_NAME' '$SPRUCE_PATH/$GAME_NAME.sh' '$SPRUCE_PATH/${GAME_NAME}Uninstaller.sh'; \
        fi; \
    else \
        rm -f '$SPRUCE_PATH/$GAME_NAME.sh' '$SPRUCE_PATH/${GAME_NAME}Uninstaller.sh'; \
    fi" 2>/dev/null

# Upload new files
echo "Uploading files..."
sshpass -p "$SPRUCE_PASS" scp -r \
  "$DIST_DIR/$GAME_NAME.sh" \
  "$DIST_DIR/${GAME_NAME}Uninstaller.sh" \
  "$DIST_DIR/$GAME_NAME" \
  "$SPRUCE_USER@$SPRUCE_IP:$SPRUCE_PATH/"

if [ $? -eq 0 ]; then
    # Optionally set production server URL in config.json (shared vars for LÖVE data dir)
    source "$SCRIPT_DIR/../shared/vars.sh"
    if [ -n "$RETROSYNC_SERVER_URL" ]; then
        echo ""
        echo "Setting server URL in config.json on device to: $RETROSYNC_SERVER_URL"
        URL="${RETROSYNC_SERVER_URL%/}"
        CONFIG_DIR="$SPRUCE_PATH/$GAME_NAME/$RETROSYNC_LOVE_DATA_SUBDIR"
        sshpass -p "$SPRUCE_PASS" ssh -o StrictHostKeyChecking=no "$SPRUCE_USER@$SPRUCE_IP" \
            "mkdir -p '$CONFIG_DIR'; if [ -f '$CONFIG_DIR/config.json' ] && command -v jq >/dev/null 2>&1; then jq -c --arg u '${URL}' '.serverUrl = \$u' '$CONFIG_DIR/config.json' > '$CONFIG_DIR/config.json.tmp' && mv '$CONFIG_DIR/config.json.tmp' '$CONFIG_DIR/config.json'; else printf '%s' '{\"serverUrl\":\"${URL}\",\"autostart\":false}' > '$CONFIG_DIR/config.json'; fi"
    fi

    echo ""
    echo "=== DEPLOYMENT COMPLETE ==="
else
    echo ""
    echo "=== DEPLOYMENT FAILED ==="
    exit 1
fi
