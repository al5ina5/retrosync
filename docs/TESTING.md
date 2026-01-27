# RetroSync Testing Guide

## Prerequisites

- Docker and Docker Compose installed
- Node.js 18+ installed
- Python 3.9+ installed
- A web browser

## Local Testing

### 1. Start Infrastructure

First, start MinIO (S3-compatible storage):

```bash
cd /path/to/retrosync
docker-compose up -d
```

Verify MinIO is running:
- API: http://localhost:9000
- Console: http://localhost:9001 (login: minioadmin/minioadmin)

### 2. Set Up Backend

```bash
cd backend

# Install dependencies
npm install

# Set up database
npx prisma generate
npx prisma db push

# Start development server
npm run dev
```

The backend will be available at http://localhost:3000

### 3. Set Up Python Client

```bash
cd ../client

# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install in development mode
pip install -e .
```

### 4. Test the Complete Flow

#### A. Create User Account

1. Open http://localhost:3000 in your browser
2. Click "Get Started"
3. Register with email and password
4. You'll be redirected to the dashboard

#### B. Generate Pairing Code

1. In the dashboard, click "Add Device"
2. Copy the 6-digit pairing code
3. Keep this browser tab open

#### C. Pair Python Client

In a terminal:

```bash
# Run setup wizard
python -m retrosync setup

# Follow the prompts:
# - Accept auto-detected settings or customize
# - Enter API URL: http://localhost:3000
# - Choose "Enter code from web dashboard"
# - Enter the 6-digit code from step B
```

#### D. Start the Daemon

```bash
# Start the RetroSync daemon
python -m retrosync start
```

You should see:
- "Performing initial sync..."
- "File watcher started"
- Status display showing device info

#### E. Test File Sync

Create a test save file in one of the watched directories:

```bash
# Find watch paths (shown in daemon output or run)
python -m retrosync status

# Create a test save file
# Example for Mac/Linux:
echo "test save data" > ~/.config/retroarch/saves/test_game.srm
```

Watch the daemon output - you should see:
- "File changed: /path/to/test_game.srm"
- "Uploading test_game.srm"
- "Successfully uploaded test_game.srm"

#### F. Verify in MinIO Console

1. Open http://localhost:9001
2. Login: minioadmin/minioadmin
3. Navigate to "Object Browser" → "retrosync-saves"
4. You should see your uploaded file

#### G. Verify in Dashboard

1. Return to the dashboard at http://localhost:3000/dashboard
2. Click "Device Management"
3. You should see the sync event in the activity log

## Testing Multi-Device Sync

### Simulating Multiple Devices

You can test multi-device sync on a single machine by:

1. Create a second configuration directory:

```bash
# Pair a second device with a different config directory
python -m retrosync setup --config-dir ~/.retrosync-device2
```

2. Start the second daemon in another terminal:

```bash
python -m retrosync start --config-dir ~/.retrosync-device2
```

3. Create a save file in device 1's watch path
4. Wait 5 minutes for device 2 to sync (or modify the sync interval)
5. Verify the file appears in device 2's watch path

## Common Issues

### "Client is not configured"

- Run `python -m retrosync setup` first
- Check that `~/.retrosync/config.json` exists

### "Failed to connect to API"

- Verify backend is running: `curl http://localhost:3000`
- Check API URL in config: `python -m retrosync status`

### "Failed to upload to S3"

- Verify MinIO is running: `docker ps`
- Check MinIO console: http://localhost:9001
- Verify bucket exists: "retrosync-saves"

### "No paths to watch"

- Run setup again and add watch paths manually
- Or edit `~/.retrosync/config.json` directly

### Database Errors

If you encounter database errors:

```bash
cd backend
rm prisma/dev.db
npx prisma db push
```

## Testing on Actual Devices

### Anbernic RG35XX+ (muOS)

1. Copy the entire `client` directory to a USB drive
2. Insert into device and copy to `/mnt/mmc/MUOS/application/RetroSync/`
3. Launch from muOS Apps menu
4. Follow on-screen pairing instructions

### Miyoo Flip (Spruce OS)

1. Copy the `client` directory to SD card
2. Navigate to Apps section
3. Launch RetroSync
4. Follow on-screen pairing instructions

## Performance Testing

### File Upload Performance

```bash
# Create multiple test files
for i in {1..10}; do
    echo "test data $i" > ~/.config/retroarch/saves/game_$i.srm
done

# Watch daemon output for upload times
```

### Sync Interval Testing

Modify sync intervals in `daemon.py`:

```python
heartbeat_interval = 10  # Test: 10 seconds instead of 60
sync_interval = 30  # Test: 30 seconds instead of 300
```

## Security Testing

### API Authentication

Test that endpoints require authentication:

```bash
# Should fail without token
curl http://localhost:3000/api/devices

# Should fail with invalid token
curl -H "Authorization: Bearer invalid" http://localhost:3000/api/devices
```

### API Key Authentication

Test device endpoints:

```bash
# Should fail without API key
curl http://localhost:3000/api/sync/heartbeat

# Should work with valid API key (get from config.json)
curl -H "X-API-Key: your-api-key-here" http://localhost:3000/api/sync/heartbeat
```

## Cleanup

To reset everything:

```bash
# Stop and remove containers
docker-compose down -v

# Remove database
rm backend/prisma/dev.db

# Remove client config
rm -rf ~/.retrosync

# Reinstall and restart
```
