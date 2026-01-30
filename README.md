# RetroSync

**Cloud sync service for retro gaming save files across Anbernic, Miyoo handhelds, and PC.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Discord](https://img.shields.io/discord/1234567890)](https://discord.gg/retrosync)

---

## What is RetroSync?

RetroSync automatically backs up your game save files to the cloud and syncs them across all your devices. Never lose a save again!

### Features

- 🔄 **Automatic Sync** - Saves sync when files change
- 📱 **Multi-Platform** - Anbernic, Miyoo, Windows, macOS, Linux
- ☁️ **Cloud Storage** - Access saves from anywhere
- 🔗 **Simple Pairing** - 6-digit code to link devices
- 🛡️ **Safe & Secure** - Your saves, your data
- 🆓 **Free Tier** - Unlimited devices, 1GB storage

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

**Linux:**
```bash
pip3 install retrosync && retrosync setup
```

### 3-Step Setup

1. **Install RetroSync** on your device
2. **Create account** at your RetroSync server URL
3. **Pair device** using the 6-digit code

---

## Documentation

### For Users

| Guide | Description |
|-------|-------------|
| [Installation Guide](docs/INSTALLATION.md) | Step-by-step installation for all platforms |
| [Usage Guide](docs/USAGE.md) | How to use RetroSync - accounts, pairing, sync |
| [Compatibility List](docs/COMPATIBILITY.md) | Supported devices, emulators, file types |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and solutions |

### For Developers

| Guide | Description |
|-------|-------------|
| [Architecture](ARCHITECTURE.md) | Technical overview of the system |
| [Developer Guide](DEVELOPER.md) | Setup, development workflow, testing |
| [API Reference](API.md) | REST API documentation |
| [Feedback & Review](FEEDBACK.md) | Code review and improvement suggestions |

---

## Supported Platforms

### Handheld Devices

| Device | OS | Status |
|--------|-----|--------|
| Anbernic RG35XX+ | muOS | ✅ Stable |
| Miyoo Flip | Spruce OS | ✅ Stable |
| Anbernic RG35XX H | muOS | ✅ Should Work |
| Miyoo Mini | Spruce OS | ⚠️ Limited |

### Desktop Platforms

| Platform | Status |
|----------|--------|
| Windows 10/11 | ✅ Stable |
| macOS 11+ | ✅ Stable |
| Linux (Ubuntu 20.04+) | ✅ Stable |

### Save File Support

**Battery Saves:**
- `.srm` - SRAM saves (most common)
- `.sav` - Generic saves
- `.eep`, `.fla` - EEPROM/Flash saves
- `.mpk` - N64 controller pak

**Save States:**
- `.state`, `.st` - Emulator save states

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         RetroSync System                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Devices ───▶ Backend (Next.js) ───▶ Storage (MinIO + SQLite)  │
│      │                │                        │                 │
│      │                │                        │                 │
│      ▼                ▼                        ▼                 │
│   Clients       API + Auth             Save Files + Metadata     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Technology Stack:**
- **Backend:** Next.js 14, Prisma, SQLite, JWT
- **Storage:** MinIO (S3-compatible)
- **Clients:** Python, Lua/LÖVE, Shell
- **Container:** Docker Compose

---

## Installation

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for backend development)
- Python 3.9+ (for client)

### Setup

```bash
# 1. Start infrastructure
docker-compose up -d

# 2. Set up backend
cd backend
cp .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run dev

# 3. Set up Python client
cd ../client
pip install -e .
python -m retrosync setup
```

**Services Available:**
- Backend API: http://localhost:3000
- MinIO Console: http://localhost:9001 (admin/admin)

---

## Project Structure

```
retrosync/
├── backend/              # Next.js API + Web UI
│   ├── src/
│   │   ├── app/         # Pages + API routes
│   │   └── lib/         # Utilities (S3, auth, prisma)
│   └── prisma/          # Database schema
├── client/              # Python daemon
│   └── retrosync/       # Main package
├── miyoo-shell/         # Shell-only client
├── miyoo-package/       # Device distribution
├── docs/                # User documentation
├── ARCHITECTURE.md      # Technical architecture
├── DEVELOPER.md         # Developer guide
├── FEEDBACK.md          # Code review
└── docker-compose.yml   # Infrastructure
```

---

## Development

### Running Tests

```bash
# Backend tests
cd backend && npm test

# Client tests
cd client && pytest
```

### Building

```bash
# Build backend Docker image
cd backend && docker build -t retrosync-backend .

# Build Python package
cd client && python -m build

# Build LÖVE app
zip -r RetroSync.love main.lua conf.lua
```

### Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

See [DEVELOPER.md](DEVELOPER.md) for detailed contribution guidelines.

---

## Support

- **GitHub Issues:** Report bugs and request features
- **Discord:** Join our community server
- **Email:** support@retrosync.example.com (Pro tier)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [LÖVE](https://love2d.org/) - For the Lua game framework
- [Next.js](https://nextjs.org/) - For the React framework
- [Prisma](https://prisma.io/) - For the ORM
- [MinIO](https://min.io/) - For S3-compatible storage
- [Watchdog](https://github.com/gorakhargosh/watchdog) - For file system monitoring
