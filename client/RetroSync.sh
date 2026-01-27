#!/bin/bash
# RetroSync launcher script for handheld devices

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    echo "Please install Python 3.9 or later"
    exit 1
fi

# Check if setup has been run
CONFIG_FILE="$HOME/.retrosync/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "RetroSync is not configured."
    echo "Running setup wizard..."
    python3 -m retrosync setup
else
    # Start the daemon
    python3 -m retrosync start
fi
