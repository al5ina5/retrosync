#!/bin/bash
# debug-device.sh - Diagnose RetroSync watcher issues on device
#
# Usage: ./debug-device.sh

set -u

SPRUCE_IP="10.0.0.94"
SPRUCE_USER="spruce"
SPRUCE_PASS="happygaming"
RETROSYNC_PATH="/mnt/sdcard/Roms/PORTS/RetroSync"
SAVES_PATH="/mnt/sdcard/Saves/saves"

SSH_OPTS="-T -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3"

echo "=== RetroSync Device Debugger ==="
echo "Target: $SPRUCE_USER@$SPRUCE_IP"
echo ""

# Test basic connectivity
echo "1. Testing SSH connection..."
if ! sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "echo 'OK'" 2>/dev/null; then
    echo "   FAILED: Cannot connect to device"
    echo "   - Is the device powered on?"
    echo "   - Is SSH enabled?"
    echo "   - Is the IP correct?"
    exit 1
fi
echo "   SUCCESS: Connected"
echo ""

# Check if watcher is running
echo "2. Checking if watcher process is running..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    echo '--- Process check ---'
    ps aux 2>/dev/null | grep -E 'watcher|RetroSync' | grep -v grep || echo 'No watcher process found'
    echo ''
    echo '--- PID file ---'
    if [ -f '$RETROSYNC_PATH/data/watcher.pid' ]; then
        pid=\$(cat '$RETROSYNC_PATH/data/watcher.pid')
        echo \"PID file contains: \$pid\"
        if kill -0 \"\$pid\" 2>/dev/null; then
            echo \"Process \$pid is RUNNING\"
        else
            echo \"Process \$pid is NOT running (stale PID file)\"
        fi
    else
        echo 'No PID file found'
    fi
"
echo ""

# Check API key
echo "3. Checking device pairing (API key)..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    if [ -f '$RETROSYNC_PATH/data/api_key' ]; then
        key=\$(cat '$RETROSYNC_PATH/data/api_key' | head -c 20)
        echo \"API key present: \${key}...\"
    else
        echo 'NO API KEY - Device not paired!'
    fi
    echo ''
    echo '--- Server URL ---'
    if [ -f '$RETROSYNC_PATH/data/server_url' ]; then
        cat '$RETROSYNC_PATH/data/server_url'
    else
        echo 'Using default: https://retrosync.vercel.app'
    fi
"
echo ""

# Check save files
echo "4. Listing save files in gpSP folder..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    echo '--- gpSP saves ---'
    ls -la '$SAVES_PATH/gpSP/' 2>/dev/null || echo 'gpSP folder not found'
    echo ''
    echo '--- All .srm/.sav files (first 20) ---'
    find '$SAVES_PATH' -type f \( -name '*.srm' -o -name '*.sav' \) 2>/dev/null | head -20
"
echo ""

# Check watcher state
echo "5. Checking watcher state file..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    echo '--- State file info ---'
    ls -la '$RETROSYNC_PATH/data/watcher_state.tsv' 2>/dev/null || echo 'No state file'
    echo ''
    echo '--- State file contents (last 10 entries) ---'
    tail -10 '$RETROSYNC_PATH/data/watcher_state.tsv' 2>/dev/null || echo 'Empty or missing'
"
echo ""

# Check recent logs
echo "6. Recent watcher logs (last 100 lines)..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    tail -100 '$RETROSYNC_PATH/data/watcher.log' 2>/dev/null || echo 'No log file found'
"
echo ""

# Check for Minish Cap specifically
echo "7. Looking for Minish Cap save file..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    echo '--- Minish Cap files ---'
    find '$SAVES_PATH' -type f -name '*Minish*' 2>/dev/null
    echo ''
    echo '--- File details ---'
    file_path=\"\$(find '$SAVES_PATH' -type f -name '*Minish*' 2>/dev/null | head -1)\"
    if [ -n \"\$file_path\" ]; then
        ls -la \"\$file_path\"
        stat \"\$file_path\" 2>/dev/null || busybox stat \"\$file_path\" 2>/dev/null
    else
        echo 'Minish Cap save not found'
    fi
"
echo ""

# Check if file is in state
echo "8. Checking if Minish Cap is in watcher state..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    grep -i 'minish' '$RETROSYNC_PATH/data/watcher_state.tsv' 2>/dev/null || echo 'Not in state file'
"
echo ""

# Test curl connectivity to server
echo "9. Testing API connectivity from device..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    server_url=\$(cat '$RETROSYNC_PATH/data/server_url' 2>/dev/null || echo 'https://retrosync.vercel.app')
    echo \"Testing: \$server_url\"
    curl -sS --connect-timeout 5 \"\$server_url/api/devices/status\" 2>&1 | head -c 500
    echo ''
"
echo ""

echo "=== Debug Complete ==="
