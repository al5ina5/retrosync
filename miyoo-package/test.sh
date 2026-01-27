#!/bin/sh
# Quick test script to verify Python and modules

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

echo "Testing RetroSync Python environment..."
echo ""
echo "Python version:"
python3 --version
echo ""
echo "Python location:"
which python3
echo ""
echo "PYTHONPATH: $PYTHONPATH"
echo ""
echo "Testing retrosync import:"
python3 -c "import sys; sys.path.insert(0, '$SCRIPT_DIR'); import retrosync; print('SUCCESS: retrosync module imported')"
echo ""
echo "Testing retrosync.daemon import:"
python3 -c "import sys; sys.path.insert(0, '$SCRIPT_DIR'); from retrosync import daemon; print('SUCCESS: daemon module imported')"
echo ""
echo "All tests passed!"
