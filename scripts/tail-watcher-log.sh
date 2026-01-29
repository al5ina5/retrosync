#!/bin/bash
# tail-watcher-log.sh - Live tail of watcher log from device
#
# Usage: ./tail-watcher-log.sh [lines]

set -u

SPRUCE_IP="10.0.0.94"
SPRUCE_USER="spruce"
SPRUCE_PASS="happygaming"
RETROSYNC_PATH="/mnt/sdcard/Roms/PORTS/RetroSync"

LINES="${1:-50}"

SSH_OPTS="-T -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=5"

echo "=== Tailing watcher.log (last $LINES lines, then live) ==="
echo "Press Ctrl+C to stop"
echo ""

sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    tail -f -n $LINES '$RETROSYNC_PATH/data/watcher.log' 2>/dev/null || {
        echo 'Log file not found. Checking if watcher is running...'
        ps aux | grep watcher | grep -v grep
    }
"
