#!/bin/bash
# Shared build vars: LÖVE data dir subpath and identity (must match conf.lua).
# Source from build scripts: source "$SCRIPT_DIR/shared/vars.sh" or similar.

RETROSYNC_LOVE_IDENTITY="retrosync"
# LÖVE getSaveDirectory() = $XDG_DATA_HOME/love/$RETROSYNC_LOVE_IDENTITY when XDG_DATA_HOME is set (e.g. PortMaster).
RETROSYNC_LOVE_DATA_SUBDIR="saves/love/${RETROSYNC_LOVE_IDENTITY}"
DEFAULT_SERVER_URL="https://retrosync.vercel.app"
