#!/bin/bash

# RetroSync Development Startup Script
# Runs without Docker (for development/testing)

set -e

echo "🎮 Starting RetroSync (Development Mode)..."
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Get local IP
if [[ "$OSTYPE" == "darwin"* ]]; then
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
else
    LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
fi

# Check if backend .env exists
if [ ! -f backend/.env ]; then
    echo "📝 Creating backend .env file..."
    cp .env.example backend/.env
    sed -i.bak "s|NEXT_PUBLIC_API_URL=http://localhost:3000|NEXT_PUBLIC_API_URL=http://${LOCAL_IP}:3000|g" backend/.env
    rm -f backend/.env.bak
fi

# Check if Node modules are installed
if [ ! -d "backend/node_modules" ]; then
    echo "📦 Installing backend dependencies..."
    cd backend
    npm install
    cd ..
fi

# Set up database
echo "🗄️  Setting up database..."
cd backend
npx prisma generate > /dev/null 2>&1
npx prisma db push --accept-data-loss > /dev/null 2>&1
cd ..

# Start MinIO with Docker (minimal requirement)
echo "🚀 Starting MinIO..."
docker-compose up -d minio createbuckets 2>&1 | grep -v "Container.*Creating" | grep -v "Container.*Starting" || true

sleep 5

# Start backend in background
echo "🌐 Starting backend server..."
cd backend
npm run dev > ../backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Wait for backend to be ready
echo "⏳ Waiting for backend to start..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo ""
echo "✅ RetroSync is running!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Open your browser:"
echo "   http://${LOCAL_IP}:3000"
echo ""
echo "📱 For Miyoo device, use:"
echo "   http://${LOCAL_IP}:3000"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Backend PID: $BACKEND_PID (saved to .backend.pid)"
echo $BACKEND_PID > .backend.pid
echo ""
echo "To stop: kill $BACKEND_PID && docker-compose down"
echo "Or run: ./stop-dev.sh"
echo ""

# Keep script running
echo "Press Ctrl+C to stop all services..."
trap "echo ''; echo 'Stopping services...'; kill $BACKEND_PID 2>/dev/null; docker-compose down 2>/dev/null; exit 0" INT TERM

wait $BACKEND_PID
