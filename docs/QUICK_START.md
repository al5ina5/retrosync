# RetroSync Quick Start Guide

## Overview

RetroSync automatically syncs retro gaming save files across multiple devices. This guide will get you up and running in minutes.

## System Requirements

- **Server**: Docker, Node.js 18+
- **Clients**: Python 3.9+
- **Supported Devices**:
  - Anbernic RG35XX+ (muOS)
  - Miyoo Flip (Spruce OS)
  - Windows PC
  - Mac
  - Linux

## Installation

### Step 1: Start the Server

```bash
# Clone or navigate to the RetroSync directory
cd retrosync

# Start MinIO (S3 storage)
docker-compose up -d

# Install and start backend
cd backend
npm install
npx prisma generate
npx prisma db push
npm run dev
```

Server will be running at http://localhost:3000

### Step 2: Create an Account

1. Open http://localhost:3000 in your browser
2. Click "Get Started"
3. Enter your email and password
4. Click "Create Account"

### Step 3: Set Up Your First Device

#### On PC (Windows/Mac/Linux):

```bash
# Navigate to client directory
cd ../client

# Install RetroSync
pip install -e .

# Run setup wizard
python -m retrosync setup
```

The setup wizard will:
- Auto-detect your OS and save file locations
- Prompt for API URL (use http://localhost:3000)
- Ask you to enter a pairing code

#### Generate Pairing Code:

1. In the web dashboard, click "Add Device"
2. Copy the 6-digit code
3. Enter it in the setup wizard

#### On Handheld Device (Anbernic/Miyoo):

1. Copy the `client` folder to your device
2. Launch RetroSync from the Apps menu
3. The device will display a pairing code
4. Enter the code in your web dashboard

### Step 4: Start Syncing

```bash
# Start the RetroSync daemon
python -m retrosync start
```

That's it! Your save files will now sync automatically.

## What Gets Synced?

RetroSync watches for common save file formats:
- `.srm` - SNES/Genesis saves
- `.sav` - General save files
- `.state` - Save states
- `.mpk` - N64 controller pak
- And more...

### Default Watch Locations:

**muOS (RG35XX+)**:
- `/mnt/mmc/MUOS/save/`

**Spruce OS (Miyoo Flip)**:
- `/mnt/SDCARD/Saves/`

**Windows**:
- `%APPDATA%\RetroArch\saves\`
- `Documents\RetroArch\saves\`

**Mac**:
- `~/Library/Application Support/RetroArch/saves/`

**Linux**:
- `~/.config/retroarch/saves/`
- `~/.local/share/retroarch/saves/`

## How It Works

1. **File Changes**: RetroSync monitors your save directories
2. **Automatic Upload**: When a save file changes, it's uploaded immediately
3. **Periodic Download**: Every 5 minutes, checks for updates from other devices
4. **Conflict Resolution**: Last-write-wins (newer file overwrites older)

## Common Commands

```bash
# Start daemon
python -m retrosync start

# Check status
python -m retrosync status

# Run setup again
python -m retrosync setup

# Use custom config directory
python -m retrosync start --config-dir /path/to/config
```

## Viewing Sync Activity

1. Open http://localhost:3000/dashboard
2. Click "Device Management"
3. View recent sync events with timestamps

## Adding More Devices

1. In dashboard, click "Add Device"
2. Copy the pairing code
3. Run setup on the new device
4. Enter the pairing code

All your devices will now sync automatically!

## Troubleshooting

### "Client is not configured"
Run `python -m retrosync setup`

### "Failed to connect to API"
- Check backend is running: http://localhost:3000
- Verify API URL in config

### "No paths to watch"
- Run setup and add paths manually
- Or edit `~/.retrosync/config.json`

### Files not syncing
- Check daemon is running
- Verify file is in a watched directory
- Check file extension is supported

## Production Deployment

For production use:

1. **Change default credentials** in `.env`:
   ```
   MINIO_ROOT_USER=your-secure-username
   MINIO_ROOT_PASSWORD=your-secure-password
   JWT_SECRET=your-very-long-random-secret
   ```

2. **Use HTTPS** for API communication

3. **Set up proper backups** for:
   - SQLite database (`backend/prisma/dev.db`)
   - MinIO data volume

4. **Consider using PostgreSQL** instead of SQLite for production

## Next Steps

- Read [TESTING.md](./TESTING.md) for detailed testing instructions
- Check [device-testing.md](./device-testing.md) for device-specific guides
- Review [API documentation](./API.md) for custom integrations

## Support

- Report issues: https://github.com/anthropics/retrosync/issues
- Documentation: See `/docs` directory

## License

MIT License - see LICENSE file
