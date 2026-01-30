# RetroSync Developer Guide

**Version:** 1.0.0  
**Last Updated:** January 30, 2026

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project Structure](#project-structure)
3. [Development Setup](#development-setup)
4. [Running the Server](#running-the-server)
5. [Client Development](#client-development)
6. [Testing](#testing)
7. [Debugging](#debugging)
8. [Deployment](#deployment)

---

## Quick Start

### 3-Command Setup

```bash
# 1. Clone
git clone https://github.com/al5ina5/retrosync.git
cd retrosync

# 2. Start server
node server.js

# 3. Test in browser
# Open http://localhost:4000
```

### Verify Installation

```bash
# Check server is running
curl http://localhost:4000/api/health

# Should return JSON (even if minimal)
```

---

## Project Structure

```
retrosync/
├── server.js              # Main server (Node.js)
├── data.json              # Runtime database (auto-created)
├── saves/                 # Save file storage (auto-created)
├── RetroSync.love         # LÖVE packaged app
├── RetroSync.lua          # LÖVE source
├── RetroSync.sh           # Shell client launcher
├── retrosync_client.py    # Python client
├── retrosync_portal.py    # Standalone portal (Flask)
├── upload_saves.py        # CLI upload tool
├── main.lua               # Lua client source
├── conf.lua               # LÖVE config
├── docker-compose.yml     # Docker setup (MinIO)
├── miyoo-package/         # Device distribution
├── miyoo-shell/           # Shell-only client
└── docs/                  # Documentation
```

### Key Files

| File | Purpose |
|------|---------|
| `server.js` | Main HTTP server, API, web UI |
| `retrosync_client.py` | Python client with framebuffer UI |
| `main.lua` | LÖVE/Lua client source |
| `RetroSync.sh` | Shell script launcher |

---

## Development Setup

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 18+ | Run server.js |
| Python | 3.9+ | Run client scripts |
| Git | 2.0+ | Version control |

### Clone and Install

```bash
git clone https://github.com/al5ina5/retrosync.git
cd retrosync

# No npm install needed - server.js has no dependencies!
# Python packages:
pip3 install -r client/requirements.txt  # If exists
```

---

## Running the Server

### Basic Start

```bash
node server.js
```

**Output:**
```
==========================================
   RetroSync - Cloud Saves Platform
==========================================
   Portal: http://0.0.0.0:4000/
   ...
==========================================
```

### Custom Port

```bash
PORT=3000 node server.js
```

### Check Logs

```bash
# Server logs to stdout
node server.js

# Or check backend.log if configured
tail -f backend.log
```

### Restarting

```bash
# Ctrl+C to stop
# Or kill process
pkill -f "node server.js"

# Restart
node server.js
```

---

## Client Development

### Python Client

**Location:** `retrosync_client.py`

**Run:**
```bash
python3 retrosync_client.py
```

**Key Functions:**
- `load_device_id()` - Get or create 6-digit code
- `register_device()` - Call `/api/register`
- `get_server_status()` - Poll `/api/status/{code}`
- `upload_save(filepath)` - POST to `/api/saves/upload`
- `find_save_files()` - Scan for .srm, .state, etc.

**Configuration:**
```python
SERVER_URL = "http://10.0.0.245:4000"  # Change for your setup
DEVICE_ID_FILE = "/mnt/SDCARD/Saves/retrosync/device_id"
SAVE_DIR = "/mnt/SDCARD/Saves/retrosync"
```

### LÖVE Client

**Location:** `main.lua`

**Run:**
```bash
love RetroSync.love
# OR
love main.lua
```

**Key States:**
- `STATE_WAITING` - Show pairing code
- `STATE_CONNECTED` - Connected, ready to upload
- `STATE_UPLOADING` - Uploading saves
- `STATE_SUCCESS` - Upload complete

**HTTP Functions:**
- `httpPost(url, data)` - POST request
- `httpGet(url)` - GET request
- Uses `curl` via `os.execute()`

### Shell Client

**Location:** `RetroSync.sh`, `miyoo-shell/`

**Run:**
```bash
./RetroSync.sh
```

**Note:** Shell client is basic and may be incomplete.

---

## Testing

### Manual API Testing

**Test server is running:**
```bash
curl http://localhost:4000/api/health
```

**Test user registration:**
```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "test123"}'
```

**Test device registration:**
```bash
curl -X POST http://localhost:4000/api/register \
  -H "Content-Type: application/json" \
  -d '{"code": "999999", "game_system": "test"}'
```

**Test device claiming:**
```bash
curl -X POST http://localhost:4000/api/claim \
  -H "Content-Type: application/json" \
  -d '{"code": "999999", "email": "test@example.com"}'
```

**Test save upload:**
```bash
curl -X POST http://localhost:4000/api/saves/upload \
  -H "Content-Type: application/json" \
  -d '{"code": "999999", "filename": "test.srm", "game_name": "Test"}'
```

### End-to-End Testing

1. **Start server:** `node server.js`
2. **Open browser:** http://localhost:4000
3. **Create account**
4. **Start Python client:** `python3 retrosync_client.py`
5. **Note pairing code** displayed
6. **Enter code** in web dashboard
7. **Verify connection** on client
8. **Upload saves** (press A or trigger auto)

### Device Testing

See [docs/TESTING.md](docs/TESTING.md) for device-specific testing.

---

## Debugging

### Server Debugging

**Enable verbose logging:**
```bash
# Edit server.js to add more console.log
node server.js
```

**Check data file:**
```bash
cat data.json | python3 -m json.tool
```

**Check saves directory:**
```bash
ls -la saves/
ls -la saves/123456/  # Replace with device code
```

### Client Debugging

**Python client logs:**
```bash
python3 retrosync_client.py 2>&1 | tee client.log
```

**Check device ID:**
```bash
cat /mnt/SDCARD/Saves/retrosync/device_id
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Connection refused" | Check server is running on correct port |
| "Device not found" | Device must call `/api/register` first |
| "Invalid code" | Code must be 6 digits, registered first |
| "Account not found" | Create account before claiming device |

---

## Deployment

### Production Server

**Recommended: Use a process manager**

```bash
# Install pm2
npm install -g pm2

# Start server
pm2 start server.js --name retrosync

# Setup startup script
pm2 startup

# Save process list
pm2 save
```

### Docker

```bash
# Build image
docker build -t retrosync .

# Run container
docker run -d \
  -p 4000:4000 \
  -v retrosync_data:/data \
  -v retrosync_saves:/saves \
  --name retrosync \
  retrosync
```

### Systemd Service

Create `/etc/systemd/system/retrosync.service`:

```ini
[Unit]
Description=RetroSync Server
After=network.target

[Service]
Type=simple
User=retrosync
WorkingDirectory=/home/alsinas/clawd/retrosync
ExecStart=/usr/bin/node server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl enable retrosync
sudo systemctl start retrosync
```

### Environment Variables

```bash
# In production, use env vars or .env file
PORT=4000
DATA_DIR=/var/lib/retrosync
```

---

## Code Style

### JavaScript (server.js)

- No linting configured
- Use `const` and `let`
- CamelCase for variables
- Console.log for debugging

### Python (client)

- PEP 8 style
- Use type hints where helpful
- Logging module for output

### Lua (client)

- Follow LÖVE conventions
- Local scope variables
- Descriptive function names

---

## Adding Features

### Add New API Endpoint

Edit `server.js`:

```javascript
// Add endpoint handler
if (pathname === '/api/my/new/endpoint' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
        try {
            const data = JSON.parse(body);
            // Handle request
            sendJSON(res, { success: true });
        } catch (e) {
            sendJSON(res, { success: false, message: 'Invalid JSON' }, 400);
        }
    });
    return;
}
```

### Add New Save Type

Edit `retrosync_client.py` - `find_save_files()`:

```python
def find_save_files():
    save_files = []
    for loc in save_locations:
        if os.path.exists(loc):
            for root, dirs, files in os.walk(loc):
                for f in files:
                    if f.endswith(('.srm', '.sav', '.state', '.NEW_EXT')):
                        save_files.append(os.path.join(root, f))
    return sorted(set(save_files))
```

---

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [API.md](API.md) - API reference
- [FEEDBACK.md](FEEDBACK.md) - Code review
- [docs/INSTALLATION.md](docs/INSTALLATION.md) - User installation
