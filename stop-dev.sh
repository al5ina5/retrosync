#!/bin/bash

echo "🛑 Stopping RetroSync..."

# Stop backend
if [ -f .backend.pid ]; then
    PID=$(cat .backend.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "Stopping backend (PID: $PID)..."
        kill $PID
    fi
    rm -f .backend.pid
fi

# Stop MinIO
echo "Stopping MinIO..."
docker-compose down 2>/dev/null || true

echo "✅ Services stopped"
