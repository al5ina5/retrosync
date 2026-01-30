#!/bin/sh
# Minimal test script for muOS init - creates a file to prove it ran
echo "muOS init test ran at $(date)" > /mnt/mmc/MUOS/init/test-ran.txt 2>/dev/null || echo "muOS init test ran at $(date)" > /mnt/sdcard/MUOS/init/test-ran.txt
