#!/bin/bash
# deploy-muos.sh
# Builds and deploys RetroSync to muOS devices via SFTP
#
# Usage: ./deploy-muos.sh
#
# Note: muOS uses SFTPGo which only supports file transfers (no shell commands).
#
# muOS deployment structure:
#   /SD2 (sdcard)/Roms/PORTS/RetroSync.sh           - Launcher script
#   /SD2 (sdcard)/Roms/PORTS/RetroSyncUninstaller.sh - Uninstaller script  
#   /SD2 (sdcard)/ports/RetroSync/                   - Game folder
#
# Configuration via environment variables or .env file:
#   MUOS_IP     - Device IP address (default: 10.0.0.79)
#   MUOS_PORT   - SFTP port (default: 2022)
#   MUOS_USER   - SFTP username (default: muos)
#   MUOS_PASS   - SFTP password (default: muos)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CLIENT_DIR="$PROJECT_ROOT/client"
GAME_NAME="RetroSync"
DIST_DIR="$CLIENT_DIR/dist/portmaster"

# Load environment variables from .env file (if present)
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        if [[ "$key" == MUOS_* ]]; then
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            export "$key=$value"
        fi
    done < "$ENV_FILE"
fi

cd "$CLIENT_DIR"

echo "=== Building $GAME_NAME ==="
"$SCRIPT_DIR/build.sh"

echo ""
echo "=== Deploying to muOS via SFTP ==="

# --- muOS Configuration ---
MUOS_IP="${MUOS_IP:-10.0.0.79}"
MUOS_PORT="${MUOS_PORT:-2022}"
MUOS_USER="${MUOS_USER:-muos}"
MUOS_PASS="${MUOS_PASS:-muos}"

# muOS paths (SFTP uses virtual paths with spaces)
SCRIPTS_PATH='/SD2 (sdcard)/Roms/PORTS'
PORTS_PATH='/SD2 (sdcard)/ports'

echo "Target: $MUOS_USER@$MUOS_IP:$MUOS_PORT"
echo "Scripts: $SCRIPTS_PATH"
echo "Ports:   $PORTS_PATH"

# SFTP options
SFTP_OPTS="-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -P $MUOS_PORT"

# Test connection first
echo ""
echo "Testing SFTP connection..."
if ! sshpass -p "$MUOS_PASS" sftp $SFTP_OPTS "$MUOS_USER@$MUOS_IP" <<< "bye" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to $MUOS_IP:$MUOS_PORT"
    echo "Make sure:"
    echo "  - Device is powered on"
    echo "  - SFTP is enabled in muOS settings"
    echo "  - Credentials are correct"
    exit 1
fi
echo "Connected!"

echo ""
echo "Uploading files via SFTP..."

# Create SFTP batch commands
# Note: paths with spaces need quotes in SFTP commands
sshpass -p "$MUOS_PASS" sftp $SFTP_OPTS "$MUOS_USER@$MUOS_IP" << SFTP_BATCH
# Upload launcher scripts to Roms/PORTS
put "$DIST_DIR/$GAME_NAME.sh" "$SCRIPTS_PATH/$GAME_NAME.sh"
put "$DIST_DIR/${GAME_NAME}Uninstaller.sh" "$SCRIPTS_PATH/${GAME_NAME}Uninstaller.sh"

# Create game folder and upload contents (LÖVE data dir from shared vars)
source "$SCRIPT_DIR/../shared/vars.sh"
DATA_SUBDIR="$RETROSYNC_LOVE_DATA_SUBDIR"
-mkdir "$PORTS_PATH/$GAME_NAME"
-mkdir "$PORTS_PATH/$GAME_NAME/autostart"
-mkdir "$PORTS_PATH/$GAME_NAME/saves"
-mkdir "$PORTS_PATH/$GAME_NAME/saves/love"
-mkdir "$PORTS_PATH/$GAME_NAME/$DATA_SUBDIR"

# Upload main files
put "$DIST_DIR/$GAME_NAME/RetroSync.love" "$PORTS_PATH/$GAME_NAME/RetroSync.love"
put "$DIST_DIR/$GAME_NAME/$DATA_SUBDIR/config.json" "$PORTS_PATH/$GAME_NAME/$DATA_SUBDIR/config.json"
put "$DIST_DIR/$GAME_NAME/RetroSync.gptk" "$PORTS_PATH/$GAME_NAME/RetroSync.gptk"
put "$DIST_DIR/$GAME_NAME/watcher.sh" "$PORTS_PATH/$GAME_NAME/watcher.sh"
put "$DIST_DIR/$GAME_NAME/port.json" "$PORTS_PATH/$GAME_NAME/port.json"

# Upload autostart scripts
put "$DIST_DIR/$GAME_NAME/autostart/spruce-install.sh" "$PORTS_PATH/$GAME_NAME/autostart/spruce-install.sh"
put "$DIST_DIR/$GAME_NAME/autostart/spruce-uninstall.sh" "$PORTS_PATH/$GAME_NAME/autostart/spruce-uninstall.sh"
put "$DIST_DIR/$GAME_NAME/autostart/muos-install.sh" "$PORTS_PATH/$GAME_NAME/autostart/muos-install.sh"
put "$DIST_DIR/$GAME_NAME/autostart/muos-uninstall.sh" "$PORTS_PATH/$GAME_NAME/autostart/muos-uninstall.sh"

bye
SFTP_BATCH

if [ $? -eq 0 ]; then
    echo ""
    echo "=== DEPLOYMENT COMPLETE ==="
    echo ""
    echo "Files uploaded to:"
    echo "  $SCRIPTS_PATH/$GAME_NAME.sh"
    echo "  $SCRIPTS_PATH/${GAME_NAME}Uninstaller.sh"
    echo "  $PORTS_PATH/$GAME_NAME/"
    echo ""
    echo "Next steps:"
    echo "  1. On the device, navigate to Ports"
    echo "  2. Find and run 'RetroSync'"
else
    echo ""
    echo "=== DEPLOYMENT FAILED ==="
    echo "Check the SFTP output above for errors."
    exit 1
fi
