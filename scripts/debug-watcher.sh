#!/bin/bash
# Debug script to check watcher status and file detection

SAVE_FILE="/mnt/sdcard/Saves/saves/gpSP/Legend of Zelda, The - The Minish Cap (USA).srm"
RETROSYNC_DIR="/mnt/sdcard/Roms/PORTS/RetroSync"

echo "=== File Check ==="
if [ -f "$SAVE_FILE" ]; then
    echo "File exists: $SAVE_FILE"
    echo "File size: $(stat -c '%s' "$SAVE_FILE" 2>/dev/null || busybox stat -c '%s' "$SAVE_FILE" 2>/dev/null || echo 'UNKNOWN')"
    echo "File mtime: $(stat -c '%Y' "$SAVE_FILE" 2>/dev/null || busybox stat -c '%Y' "$SAVE_FILE" 2>/dev/null || echo 'UNKNOWN')"
    echo "File ls -la:"
    ls -la "$SAVE_FILE" 2>/dev/null || echo "LS_FAILED"
else
    echo "File NOT FOUND: $SAVE_FILE"
fi

echo ""
echo "=== Watcher Status ==="
if [ -d "$RETROSYNC_DIR" ]; then
    echo "RetroSync dir exists: $RETROSYNC_DIR"
    
    if [ -f "$RETROSYNC_DIR/data/watcher.pid" ]; then
        PID=$(cat "$RETROSYNC_DIR/data/watcher.pid" 2>/dev/null)
        if kill -0 "$PID" 2>/dev/null; then
            echo "Watcher is RUNNING (PID: $PID)"
        else
            echo "Watcher PID file exists but process is NOT running (PID: $PID)"
        fi
    else
        echo "Watcher PID file NOT found - watcher may not be running"
    fi
    
    echo ""
    echo "=== Watcher Log (last 50 lines) ==="
    if [ -f "$RETROSYNC_DIR/data/watcher.log" ]; then
        tail -50 "$RETROSYNC_DIR/data/watcher.log" 2>/dev/null || echo "LOG_READ_FAILED"
    else
        echo "Watcher log NOT found"
    fi
    
    echo ""
    echo "=== Watcher State File ==="
    if [ -f "$RETROSYNC_DIR/data/watcher_state.tsv" ]; then
        echo "State file exists"
        echo "Looking for Legend of Zelda entry:"
        grep -F "Legend" "$RETROSYNC_DIR/data/watcher_state.tsv" 2>/dev/null || echo "NOT_FOUND_IN_STATE"
        echo ""
        echo "Total entries in state file:"
        wc -l "$RETROSYNC_DIR/data/watcher_state.tsv" 2>/dev/null || echo "WC_FAILED"
    else
        echo "State file NOT found"
    fi
    
    echo ""
    echo "=== API Key Check ==="
    if [ -f "$RETROSYNC_DIR/data/api_key" ]; then
        API_KEY=$(head -1 "$RETROSYNC_DIR/data/api_key" 2>/dev/null | tr -d '\r\n')
        if [ -n "$API_KEY" ]; then
            echo "API key exists: ${API_KEY:0:10}..."
        else
            echo "API key file exists but is EMPTY"
        fi
    else
        echo "API key file NOT found"
    fi
    
    echo ""
    echo "=== Server URL Check ==="
    if [ -f "$RETROSYNC_DIR/data/server_url" ]; then
        SERVER_URL=$(head -1 "$RETROSYNC_DIR/data/server_url" 2>/dev/null | tr -d '\r\n')
        echo "Server URL: ${SERVER_URL:-DEFAULT}"
    else
        echo "Server URL file NOT found (will use default)"
    fi
    
    echo ""
    echo "=== Discover Files Test ==="
    echo "Checking if file would be discovered by watcher:"
    for loc in "/mnt/SDCARD/Saves/saves" "/SD1 (mmc)/MUOS/save/file" "/MUOS/save/file" "/mnt/mmc/MUOS/save/file" "/mnt/sdcard/MUOS/save/file"; do
        if [ -d "$loc" ]; then
            echo "  Found directory: $loc"
            if find "$loc" -type f \( -name '*.sav' -o -name '*.srm' \) ! -name '*.bak' -print0 2>/dev/null | grep -qFz "Legend of Zelda"; then
                echo "    -> File WOULD be discovered here"
            fi
        fi
    done
    
    # Check the actual path
    ACTUAL_DIR=$(dirname "$SAVE_FILE")
    if [ -d "$ACTUAL_DIR" ]; then
        echo "  Checking actual save directory: $ACTUAL_DIR"
        if find "$ACTUAL_DIR" -type f \( -name '*.sav' -o -name '*.srm' \) ! -name '*.bak' -print0 2>/dev/null | grep -qFz "Legend of Zelda"; then
            echo "    -> File EXISTS in this directory"
        else
            echo "    -> File NOT found by find in this directory"
        fi
    fi
else
    echo "RetroSync directory NOT found: $RETROSYNC_DIR"
fi

echo ""
echo "=== File Path Comparison ==="
echo "Expected by user: $SAVE_FILE"
echo "Watcher scans: /mnt/SDCARD/Saves/saves (uppercase SDCARD)"
echo "Actual path: /mnt/sdcard/Saves/saves (lowercase sdcard)"
echo ""
echo "Checking if /mnt/SDCARD exists:"
if [ -d "/mnt/SDCARD" ]; then
    echo "  /mnt/SDCARD EXISTS"
else
    echo "  /mnt/SDCARD DOES NOT EXIST"
fi
echo "Checking if /mnt/sdcard exists:"
if [ -d "/mnt/sdcard" ]; then
    echo "  /mnt/sdcard EXISTS"
else
    echo "  /mnt/sdcard DOES NOT EXIST"
fi
