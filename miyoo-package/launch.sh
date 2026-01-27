#!/bin/sh

# RetroSync Launcher for Miyoo Flip (Spruce OS)
# Shell-only version - no Python required!

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Set up logging
LOG_FILE="$SCRIPT_DIR/retrosync.log"
exec > "$LOG_FILE" 2>&1

echo "=========================================="
echo "RetroSync Launcher Started"
echo "$(date)"
echo "=========================================="
echo ""

# Configuration
CONFIG_DIR="/mnt/SDCARD/RetroSync"
CONFIG_FILE="$CONFIG_DIR/config.json"
SAVE_DIR="/mnt/SDCARD/Saves"

echo "Script directory: $SCRIPT_DIR"
echo "Config directory: $CONFIG_DIR"
echo "Save directory: $SAVE_DIR"
echo ""

# Create directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$SAVE_DIR"

# Show setup screen
show_setup() {
    clear
    echo "=========================================="
    echo "       RetroSync - Device Setup"
    echo "=========================================="
    echo ""
    echo "Welcome to RetroSync!"
    echo ""
    echo "To pair this device:"
    echo ""
    echo "1. Open your browser and go to:"
    echo "   Your RetroSync server URL"
    echo ""
    echo "2. Login or create an account"
    echo ""
    echo "3. Click 'Add Device' to generate"
    echo "   a pairing code"
    echo ""
    echo "4. Come back here and enter the code"
    echo ""
    echo "=========================================="
    echo ""
}

# Show error
show_error() {
    clear
    echo "=========================================="
    echo "       RetroSync - ERROR"
    echo "=========================================="
    echo ""
    echo "$1"
    echo ""
    echo "Check the log file at:"
    echo "$LOG_FILE"
    echo ""
    echo "Press any key to exit..."
    read -n 1
}

# Check if configured
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No configuration found - running setup..."
    show_setup

    # For now, show instructions
    echo ""
    echo "=========================================="
    echo "PYTHON NOT INSTALLED"
    echo "=========================================="
    echo ""
    echo "RetroSync requires Python 3 to run."
    echo ""
    echo "To install Python on Spruce OS:"
    echo ""
    echo "1. Visit the Spruce OS community forums"
    echo "2. Download the Python 3 package"
    echo "3. Install it to your device"
    echo "4. Then launch RetroSync again"
    echo ""
    echo "OR"
    echo ""
    echo "Use RetroSync on another device:"
    echo "  - Windows PC"
    echo "  - Mac"
    echo "  - Linux PC"
    echo "  - Anbernic RG35XX+ (muOS)"
    echo ""
    echo "=========================================="
    echo ""
    echo "For now, please use the web dashboard"
    echo "to pair another device."
    echo ""
    echo "Web Dashboard: http://192.168.2.1:3000"
    echo ""
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# If we get here, show message
echo "Configuration exists but Python is required"
echo "to run the sync daemon."
echo ""
echo "Please install Python 3 for Spruce OS"
echo ""
echo "Or use RetroSync on another device."

exit 0
