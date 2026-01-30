# RetroSync Installation Guide

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Server Setup](#server-setup)
4. [Device Setup](#device-setup)
5. [PC Setup](#pc-setup)
6. [Verification](#verification)

---

## Quick Start

### The Simple Flow

1. **Start the server** on a always-on machine
2. **Install RetroSync client** on your handheld/PC
3. **Launch RetroSync** on device - it generates a 6-digit code
4. **Open http://SERVER_IP:4000** in browser
5. **Create account** or login
6. **Enter the 6-digit code** from your device
7. **Done!** - Saves sync automatically

### One-Line Server Start (Docker)

```bash
# Start server on port 4000
docker run -d -p 4000:4000 -v /home/alsinas/clawd/retrosync/data:/data retrosync/server
```

### One-Line Client Install (PC)

```bash
pip3 install retrosync
retrosync setup http://SERVER_IP:4000
```

---

## Prerequisites

### For Server

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| Node.js | 18+ | For standalone server.js |
| Storage | 100MB | For save files + database |
| Network | Port 4000 open | For device connections |
| Docker | Optional | For containerized deployment |

### For Devices

| Device | Requirements |
|--------|-------------|
| Anbernic RG35XX+ | WiFi, muOS |
| Miyoo Flip | WiFi, Spruce OS, Python 3.9+ |
| PC | Windows/macOS/Linux, Python 3.9+ |

---

## Server Setup

### Option 1: Standalone Node.js Server (Recommended for development)

```bash
# Clone and run
cd /home/alsinas/clawd/retrosync
node server.js

# Server runs on http://0.0.0.0:4000
# Data stored in /home/alsinas/clawd/retrosync/data.json
# Saves stored in /home/alsinas/clawd/retrosync/saves/
```

### Option 2: Docker

```bash
# Build image
cd /home/alsinas/clawd/retrosync
docker build -t retrosync-server .

# Run container
docker run -d \
  -p 4000:4000 \
  -v retrosync_data:/data \
  -v retrosync_saves:/saves \
  --name retrosync \
  retrosync-server
```

### Option 3: Using the provided script

```bash
./start_server.sh
```

### Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| Web Dashboard | http://YOUR_IP:4000 | Login, pair devices |
| API | http://YOUR_IP:4000/api/* | Device communication |

---

## Device Setup

### muOS (Anbernic RG35XX+)

#### Step 1: Connect to WiFi

1. Go to **Settings → WiFi**
2. Select your network
3. Enter password

#### Step 2: Install Python (if needed)

```bash
# SSH into device
ssh root@DEVICE_IP

# Install Python
opkg update
opkg install python3
```

#### Step 3: Install RetroSync

**Option A: Copy files via SSH**
```bash
scp -r retrosync_client.py root@DEVICE_IP:/mnt/SDCARD/App/RetroSync/
```

**Option B: Download release**
1. Copy `retrosync_client.py` to device
2. Place in `/mnt/SDCARD/App/RetroSync/`

#### Step 4: Run RetroSync

```bash
cd /mnt/SDCARD/App/RetroSync
python3 retrosync_client.py
```

**What you'll see:**
- 6-digit pairing code displayed on screen
- Status: "Waiting for connection..."

#### Step 5: Pair on Web Dashboard

1. Open browser to `http://YOUR_SERVER_IP:4000`
2. Click **"Get Started →"**
3. Click **"Create an account"**
4. Enter email and password
5. Click **"Create Account"**
6. Enter the **6-digit code** from your device
7. Click **"Link Device"**

#### Step 6: Verify Connection

On device, status changes to:
- **"CONNECTED!"** with your email
- Press **A** to upload saves

### Spruce OS (Miyoo Flip)

#### Step 1: Connect to WiFi

1. Go to **Settings → WiFi**
2. Select network

#### Step 2: Check Python

```bash
# Check if Python is installed
python3 --version

# If not installed, download Python package for Spruce OS
# Install via package manager
```

#### Step 3: Install RetroSync

**Using USB or SSH:**
```bash
# Copy to device
scp retrosync_client.py root@MIYOO_IP:/mnt/SDCARD/App/RetroSync/
```

#### Step 4: Run RetroSync

```bash
cd /mnt/SDCARD/App/RetroSync
python3 retrosync_client.py
```

**Controls:**
- **A** - Confirm / Upload saves
- **B** - Cancel / Exit

#### Step 5: Pair Device

1. Open `http://YOUR_SERVER_IP:4000` on PC
2. Create account / Login
3. Enter 6-digit code from Miyoo screen

---

## PC Setup

### Windows

#### Step 1: Install Python

```powershell
# Download from https://python.org/downloads/
# Run installer
# ✓ Check "Add Python to PATH"
```

#### Step 2: Install RetroSync

```cmd
pip install retrosync
```

#### Step 3: Configure

```cmd
# Edit config or run setup
retrosync setup http://YOUR_SERVER_IP:4000
```

#### Step 4: Start Daemon

```cmd
retrosync daemon
```

### macOS

```bash
# Install Python
brew install python3

# Install RetroSync
pip3 install retrosync

# Setup
retrosync setup http://YOUR_SERVER_IP:4000

# Start daemon
retrosync daemon
```

### Linux

```bash
# Ubuntu/Debian
sudo apt install python3-pip
pip3 install retrosync

# Setup
retrosync setup http://YOUR_SERVER_IP:4000

# Start daemon
retrosync daemon
```

---

## How Pairing Works (Under the Hood)

```
┌──────────┐                         ┌──────────┐
│  Device  │                         │  Server  │
└────┬─────┘                         └────┬─────┘
     │                                    │
     │  1. Generate random 6-digit code   │
     │  (e.g., "123456")                  │
     │                                    │
     │  2. POST /api/register             │
     │  {code: "123456", game_system: "miyoo-flip"} │
     │◀───────────────────────────────────│
     │  {"success": true}                 │
     │                                    │
     │  3. Display code on screen         │
     │                                    │
     │                                    │  4. User opens http://SERVER:4000
     │                                    │  5. User creates account
     │                                    │  6. User enters "123456"
     │                                    │  7. POST /api/claim
     │                                    │  {code: "123456", email: "user@email.com"}
     │◀───────────────────────────────────│
     │  8. Poll GET /api/status/123456    │
     │◀───────────────────────────────────│
     │  {"status": "CONNECTED", "email": "user@email.com"}
     │                                    │
     │  9. Device shows "CONNECTED!"      │
     │  10. Press A to upload saves       │
     │                                    │
     │  11. POST /api/saves/upload        │
     │  {code: "123456", filename: "game.srm", ...}
     │───────────────────────────────────▶│
     │                                    │  12. Save stored in /saves/123456/
```

---

## Verification

### Check Server Status

```bash
# Check server is running
curl http://localhost:4000/api/health

# Check registered devices
curl http://localhost:4000/api/status/123456
```

### Check Client Status

```bash
# Check if daemon is running
retrosync status

# View logs
cat ~/.retrosync/retrosync.log

# Check connection
retrosync check
```

### Test Sync

1. **On device:** Make a game save
2. **Check logs:** Should show upload
3. **On server:** Check `/home/alsinas/clawd/retrosync/saves/CODE/`
4. **On dashboard:** Visit `http://SERVER:4000` → Saves tab

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Connection refused" | Check server IP and port 4000 |
| "Device not found" | Make sure device app is running |
| "Invalid code" | Re-enter code from device screen |
| "Account not found" | Create account on dashboard first |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more solutions.

---

## Related Documentation

- [USAGE.md](USAGE.md) - How to use RetroSync after setup
- [COMPATIBILITY.md](COMPATIBILITY.md) - Supported devices and save types
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
