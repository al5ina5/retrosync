#!/bin/bash
# test-upload-flow.sh - Test the upload flow for a specific file
#
# Usage: ./test-upload-flow.sh [filename_pattern]
# Example: ./test-upload-flow.sh "Minish"

set -u

SPRUCE_IP="10.0.0.94"
SPRUCE_USER="spruce"
SPRUCE_PASS="happygaming"
RETROSYNC_PATH="/mnt/sdcard/Roms/PORTS/RetroSync"
SAVES_PATH="/mnt/sdcard/Saves/saves"

SSH_OPTS="-T -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=5"

PATTERN="${1:-Minish}"

echo "=== Testing Upload Flow for: $PATTERN ==="
echo ""

# Find the file
echo "1. Finding file on device..."
FILE_PATH=$(sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    find '$SAVES_PATH' -type f \( -name '*.srm' -o -name '*.sav' \) -name '*$PATTERN*' 2>/dev/null | head -1
")

if [ -z "$FILE_PATH" ]; then
    echo "   ERROR: No file matching '$PATTERN' found"
    exit 1
fi

echo "   Found: $FILE_PATH"
echo ""

# Get file stats
echo "2. Getting file statistics..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    echo '--- stat output ---'
    stat -c '%Y %s' '$FILE_PATH' 2>/dev/null || busybox stat -c '%Y %s' '$FILE_PATH' 2>/dev/null || echo 'stat failed'
    echo ''
    echo '--- ls output ---'
    ls -la '$FILE_PATH'
    echo ''
    echo '--- file size ---'
    wc -c < '$FILE_PATH'
"
echo ""

# Check state file entry
echo "3. Checking watcher state for this file..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    grep '$FILE_PATH' '$RETROSYNC_PATH/data/watcher_state.tsv' 2>/dev/null || echo 'NOT IN STATE FILE'
"
echo ""

# Check recent log entries for this file
echo "4. Recent log entries for this file..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    grep -i '$(basename "$FILE_PATH" | cut -c1-20)' '$RETROSYNC_PATH/data/watcher.log' 2>/dev/null | tail -20 || echo 'No log entries found'
"
echo ""

# Manual upload test
echo "5. Attempting manual upload test..."
sshpass -p "$SPRUCE_PASS" ssh $SSH_OPTS "$SPRUCE_USER@$SPRUCE_IP" "
    api_key=\$(cat '$RETROSYNC_PATH/data/api_key' 2>/dev/null)
    server_url=\$(cat '$RETROSYNC_PATH/data/server_url' 2>/dev/null || echo 'https://retrosync.vercel.app')
    
    if [ -z \"\$api_key\" ]; then
        echo 'ERROR: No API key found'
        exit 1
    fi
    
    # Get file info using busybox stat (the device uses BusyBox)
    stat_output=\$(busybox stat -c '%Y %s' '$FILE_PATH' 2>/dev/null)
    mtime=\$(echo \"\$stat_output\" | awk '{print \$1}')
    size=\$(echo \"\$stat_output\" | awk '{print \$2}')
    filename=\$(basename '$FILE_PATH')
    
    echo \"File: \$filename\"
    echo \"Size: \$size bytes\"
    echo \"Mtime: \$mtime\"
    echo \"Server: \$server_url\"
    echo \"API Key: \${api_key:0:20}...\"
    echo ''
    
    if [ -z \"\$mtime\" ] || [ -z \"\$size\" ]; then
        echo 'ERROR: Could not get file stats'
        exit 1
    fi
    
    # Create payload
    file_b64=\$(base64 < '$FILE_PATH' | tr -d '\n')
    local_ms=\$((mtime * 1000))
    
    payload=\"{\\\"filePath\\\":\\\"\$filename\\\",\\\"saveKey\\\":\\\"\$filename\\\",\\\"fileSize\\\":\$size,\\\"action\\\":\\\"upload\\\",\\\"fileContent\\\":\\\"\$file_b64\\\",\\\"localPath\\\":\\\"$FILE_PATH\\\",\\\"localModifiedAt\\\":\$local_ms}\"
    
    echo 'Sending upload request...'
    echo \"\$payload\" > /tmp/test_upload.json
    
    response=\$(curl -sS --connect-timeout 10 --max-time 60 \
        -H 'Content-Type: application/json' \
        -H \"x-api-key: \$api_key\" \
        --data-binary @/tmp/test_upload.json \
        \"\$server_url/api/sync/files\" 2>&1)
    
    echo ''
    echo '--- Server Response ---'
    echo \"\$response\"
    
    rm -f /tmp/test_upload.json
"
echo ""

echo "=== Test Complete ==="
