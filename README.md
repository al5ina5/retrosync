# RetroSync

Cloud sync service for retro gaming save files across Anbernic, Miyoo handhelds, and PC.

## Features

- **Local-first development** - Test entirely with Docker Compose
- **Device pairing** - Simple 6-digit code pairing flow
- **Auto-detection** - Automatically detects device type and save file locations
- **Real-time sync** - File changes trigger immediate uploads
- **Cross-device support** - Anbernic RG35XX+ (muOS), Miyoo Flip (Spruce OS), PC

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for backend)
- Python 3.9+ (for client)

### Setup

1. **Start infrastructure:**
```bash
docker-compose up -d
```

MinIO will be available at:
- API: http://localhost:9000
- Console: http://localhost:9001 (login: minioadmin/minioadmin)

2. **Set up backend:**
```bash
cd backend
cp ../.env.example .env
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run dev
```

Backend will be available at http://localhost:3000

3. **Set up Python client:**
```bash
cd client
pip install -e .
python -m retrosync setup
```

## Architecture

- **Backend**: Next.js 14 + Prisma + SQLite + JWT
- **Storage**: MinIO (S3-compatible)
- **Client**: Python 3.9+ + watchdog + boto3
- **Containers**: Docker Compose

## Project Structure

```
retrosync/
├── docker-compose.yml          # MinIO + infrastructure
├── backend/                    # Next.js (web + API)
│   ├── prisma/                 # SQLite database
│   └── src/
│       ├── app/                # Pages + API routes
│       └── lib/                # Utilities (S3, auth, prisma)
├── client/                     # Python daemon
│   ├── retrosync/              # Main package
│   └── scripts/                # Setup wizard, installers
└── docs/                       # Documentation
```

## Testing

### Local Testing

1. Start services: `docker-compose up`
2. Run backend: `cd backend && npm run dev`
3. Register user via web UI at http://localhost:3000
4. Generate pairing code
5. Run Python client: `python -m retrosync setup`
6. Create test save file in watch directory
7. Verify upload to MinIO console

### Device Testing

See [docs/device-testing.md](docs/device-testing.md) for device-specific setup instructions.

## License

MIT
