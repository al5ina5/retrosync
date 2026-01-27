#!/bin/bash

# RetroSync Startup Script
# This script starts all RetroSync services with one command

set -e

echo "🎮 Starting RetroSync..."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Get local IP address for device setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
else
    LOCAL_IP="localhost"
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env

    # Update API URL with local IP
    sed -i.bak "s|NEXT_PUBLIC_API_URL=http://localhost:3000|NEXT_PUBLIC_API_URL=http://${LOCAL_IP}:3000|g" .env
    rm -f .env.bak
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down > /dev/null 2>&1 || true

# Build and start services
echo "🏗️  Building and starting services..."
echo "   This may take a few minutes on first run..."
docker-compose build --no-cache
docker-compose up -d

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
if docker-compose ps | grep -q "retrosync-backend.*Up"; then
    echo ""
    echo "✅ RetroSync is running!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🌐 Open your browser and go to:"
    echo "   http://${LOCAL_IP}:3000"
    echo ""
    echo "📱 For devices on your network, use:"
    echo "   http://${LOCAL_IP}:3000"
    echo ""
    echo "🎮 Miyoo Device Setup:"
    echo "   1. Go to APPS on your Miyoo"
    echo "   2. Launch 'RetroSync'"
    echo "   3. Note the pairing code"
    echo "   4. Enter it at http://${LOCAL_IP}:3000"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Service URLs:"
    echo "   • Dashboard: http://${LOCAL_IP}:3000"
    echo "   • MinIO Console: http://${LOCAL_IP}:9001"
    echo "     (login: minioadmin / minioadmin)"
    echo ""
    echo "🛠️  Useful commands:"
    echo "   • View logs: docker-compose logs -f"
    echo "   • Stop services: docker-compose down"
    echo "   • Restart: ./start.sh"
    echo ""
else
    echo ""
    echo "❌ Failed to start services. Check logs with:"
    echo "   docker-compose logs"
    exit 1
fi
