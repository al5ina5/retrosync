# RetroSync Installation Guide

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [muOS Installation (Anbernic RG35XX+)](#muos-installation-anbernic-rg35xx)
4. [Spruce OS Installation (Miyoo Flip)](#spruce-os-installation-miyoo-flip)
5. [PC Installation (Windows/macOS/Linux)](#pc-installation-windowsmacoslinux)
6. [Server Installation](#server-installation)
7. [Verification](#verification)
8. [Next Steps](#next-steps)

---

## Quick Start

### One-Line Installation (PC)

**Windows (PowerShell):**
```powershell
winget install -e --id Python.Python.3.11; pip install retrosync; retrosync setup
```

**macOS (Terminal):**
```bash
brew install python3 && pip3 install retrosync && retrosync setup
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install python3-pip && pip3 install retrosync && retrosync setup
```

### 3-Step Process (All Platforms)

1. **Install RetroSync** on your device
2. **Create account** at your RetroSync server URL
3. **Pair device** using the 6-digit code

---

## Prerequisites

### General Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Internet connection | Broadband | Broadband |
| Storage space | 50MB | 100MB+ |
| Server URL | - | Your RetroSync server |

### muOS (Anbernic RG35XX+)

- Anbernic RG35XX+ handheld
- muOS firmware updated to latest version
- WiFi connectivity configured
- SSH access enabled (optional, for advanced setup)

### Spruce OS (Miyoo Flip)

- Miyoo Flip handheld
- Spruce OS updated to latest version
- WiFi connectivity configured
- Python 3.9+ (recommended) OR use shell client

### PC (Windows/macOS/Linux)

| OS | Requirements |
|----|-------------|
| Windows | Windows 10+, Python 3.9+, pip |
| macOS | macOS 11+, Python 3.9+, pip |
| Linux | Ubuntu 20.04+ or equivalent, Python 3.9+, pip |

---

## muOS Installation (Anbernic RG35XX+)

### Option 1: Easy Installation (Recommended)

1. **Connect to WiFi**
   - Go to Settings → WiFi → Select network
   - Note your server URL

2. **Download RetroSync**
   - Copy `RetroSync.sh` to `/mnt/SDCARD/App/RetroSync/`
   - Or use the built-in package installer if available

3. **Launch RetroSync**
   - Go to Apps → RetroSync
   - Select "Run Setup Wizard"

4. **Follow Setup Wizard**
   ```
   Enter server URL: http://YOUR-SERVER-IP:3000
   Choose pairing method: 2 (Enter code from web)
   ```

5. **Complete Pairing**
   - Go to server URL in browser
   - Login/create account
   - Click "Add Device"
   - Enter 6-digit code shown on device

### Option 2: SSH Installation (Advanced)

```bash
# SSH into your device
ssh root@YOUR-DEVICE-IP

# Create app directory
mkdir -p /mnt/SDCARD/App/RetroSync
cd /mnt/SDCARD/App/RetroSync

# Clone and install
git clone https://github.com/al5ina5/retrosync.git
cd retrosync/client

# Install Python client
pip3 install -e .

# Run setup
python3 -m retrosync setup http://YOUR-SERVER-IP:3000

# Start daemon
python3 -m retrosync daemon &
```

### Save File Locations (muOS)

| Emulator | Save Location |
|----------|---------------|
| RetroArch | `/mnt/SDCARD/RetroArch/saves/` |
| Picodrive | `/mnt/SDCARD/Saves/picodrive/` |
| Genesis Plus GX | `/mnt/SDCARD/Saves/genesis/` |
| PPSSPP | `/mnt/SDCARD/PPSP/savedata/` |

---

## Spruce OS Installation (Miyoo Flip)

### Option 1: Python Client (Recommended)

1. **Connect to WiFi**
   - Settings → WiFi → Select network

2. **Install Python 3** (if not installed)
   - Download Python 3 package for Spruce OS
   - Install via package manager

3. **Download RetroSync**
   ```bash
   # Copy retrosync package to device
   # Install via SSH or USB mass storage
   cd /mnt/SDCARD/App/RetroSync
   pip3 install retrosync-*.whl
   ```

4. **Run Setup**
   ```bash
   cd /mnt/SDCARD/App/RetroSync
   python3 -m retrosync setup
   ```

5. **Follow Setup Wizard**
   - Enter server URL
   - Choose pairing option

### Option 2: LÖVE App (Graphical)

1. **Download RetroSync.love**
   - Copy to `/mnt/SDCARD/App/RetroSync/RetroSync.love`

2. **Launch from Apps Menu**
   - RetroSync appears in Apps
   - Launch the application

3. **Setup via GUI**
   - Enter server URL
   - Follow on-screen instructions

### Option 3: Shell Client (No Python)

⚠️ **Experimental** - Shell client is incomplete

```bash
cd /mnt/SDCARD/App/RetroSync/miyoo-shell
./setup.sh http://YOUR-SERVER-IP:3000
./daemon.sh
```

### Save File Locations (Miyoo Flip)

| Emulator | Save Location |
|----------|---------------|
| RetroArch | `/mnt/SDCARD/RetroArch/saves/` |
| MiyooOS Cores | `/mnt/SDCARD/Saves/` |
| PocketStation | `/mnt/SDCARD/Saves/pocketsta/` |

---

## PC Installation (Windows/macOS/Linux)

### Windows Installation

1. **Install Python**
   - Download from https://python.org/downloads/
   - Run installer (✓ Add Python to PATH)

2. **Install RetroSync**
   ```cmd
   pip install retrosync
   ```

3. **Run Setup**
   ```cmd
   retrosync setup http://YOUR-SERVER-IP:3000
   ```

4. **Start Syncing**
   ```cmd
   retrosync daemon
   ```

### macOS Installation

1. **Install Python**
   ```bash
   # Using Homebrew (recommended)
   brew install python3

   # Or download from python.org
   ```

2. **Install RetroSync**
   ```bash
   pip3 install retrosync
   ```

3. **Run Setup**
   ```bash
   retrosync setup http://YOUR-SERVER-IP:3000
   ```

4. **Start Syncing**
   ```bash
   retrosync daemon
   ```

### Linux Installation

1. **Install Dependencies**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install python3-pip python3-venv

   # Fedora/RHEL
   sudo dnf install python3-pip

   # Arch
   sudo pacman -S python-pip
   ```

2. **Install RetroSync**
   ```bash
   pip3 install retrosync

   # Or for user installation
   pip3 install --user retrosync
   ```

3. **Run Setup**
   ```bash
   retrosync setup http://YOUR-SERVER-IP:3000
   ```

4. **Start Syncing**
   ```bash
   retrosync daemon
   ```

### Auto-Start on Boot (Linux)

```bash
# Create systemd service
sudo nano /etc/systemd/system/retrosync.service
```

```ini
[Unit]
Description=RetroSync Save Cloud
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
ExecStart=/usr/local/bin/retrosync daemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable retrosync
sudo systemctl start retrosync
```

---

## Server Installation

### Quick Start (Docker)

```bash
# Clone and start
git clone https://github.com/al5ina5/retrosync.git
cd retrosync
docker-compose up -d

# Access:
# - Web UI: http://localhost:3000
# - MinIO Console: http://localhost:9001 (admin/admin)
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/al5ina5/retrosync.git
cd retrosync

# Setup backend
cd backend
cp .env.example .env
# Edit .env with your settings

npm install
npx prisma generate
npx prisma db push
npm run build
npm start
```

### Environment Variables

```bash
# .env
DATABASE_URL="file:./prod.db"
JWT_SECRET="$(openssl rand -hex 32)"
MINIO_ENDPOINT="http://localhost:9000"
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin"
MINIO_BUCKET="retrosync-saves"
NEXT_PUBLIC_API_URL="http://localhost:3000"
NODE_ENV="production"
```

---

## Verification

### Check Installation

```bash
# Check RetroSync version
retrosync --version

# Check if running
retrosync status

# View logs
cat ~/.retrosync/retrosync.log
```

### Test Connection

1. **Open web dashboard** at your server URL
2. **Login** or create account
3. **Check device status** - should show as "Offline" initially
4. **Start daemon** on device:
   ```bash
   retrosync daemon
   ```
5. **Refresh dashboard** - device should show as "Online"

### Test Sync

1. **Create test save file** or modify existing save
2. **Watch logs** for upload:
   ```bash
   tail -f ~/.retrosync/retrosync.log
   ```
3. **Check dashboard** - save should appear in cloud saves
4. **Test on another device** - download from cloud

---

## Next Steps

1. **[Create Account](USAGE.md#creating-an-account)** - Set up your RetroSync account
2. **[Pair Devices](USAGE.md#pairing-devices)** - Connect your devices
3. **[Configure Save Locations](USAGE.md#configuring-save-locations)** - Set up watch directories
4. **[Learn How Sync Works](USAGE.md#how-sync-works)** - Understand the sync process

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Command not found" | Ensure pip install completed successfully |
| "Connection refused" | Check server URL and firewall |
| "Device offline" | Start daemon: `retrosync daemon` |
| "No saves found" | Configure save directory in settings |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

---

## Related Documentation

- [Usage Guide](USAGE.md)
- [Compatibility List](COMPATIBILITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Developer Guide](DEVELOPER.md)
