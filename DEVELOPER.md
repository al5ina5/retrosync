# RetroSync Developer Guide

## Table of Contents
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Building & Packaging](#building--packaging)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| **Docker** | 20.10+ | MinIO container |
| **Docker Compose** | 2.0+ | Container orchestration |
| **Node.js** | 18.0+ | Backend runtime |
| **npm** | 9.0+ | JavaScript package manager |
| **Python** | 3.9+ | Client development |
| **pip** | 21.0+ | Python package manager |
| **Git** | 2.30+ | Version control |

**Optional Tools**:
- **VS Code** - Recommended IDE with extensions
- **Postman** - API testing
- **MinIO Client (mc)** - S3 bucket management
- **jq** - JSON processing in shell scripts

### Quick Start (5 minutes)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/retrosync.git
cd retrosync

# 2. Start infrastructure
docker-compose up -d

# 3. Set up backend
cd backend
cp ../.env.example .env
npm install
npx prisma generate
npx prisma db push
npm run dev

# 4. In another terminal, set up client
cd client
pip install -e .

# 5. Open browser
# http://localhost:3000
```

You're ready to develop! 🚀

---

## Development Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/retrosync.git
cd retrosync
```

### 2. Environment Configuration

Create `.env` file in project root:

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Database
DATABASE_URL="file:./dev.db"

# JWT Authentication
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"

# MinIO Configuration
MINIO_ENDPOINT="http://localhost:9000"
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin"
MINIO_BUCKET="retrosync-saves"

# API Configuration
NEXT_PUBLIC_API_URL="http://localhost:3000"
NODE_ENV="development"
```

### 3. Start MinIO Storage

```bash
docker-compose up -d
```

**Verify MinIO**:
- API: http://localhost:9000
- Console: http://localhost:9001
- Login: minioadmin / minioadmin

**Create bucket** (if not auto-created):
```bash
# Install mc (MinIO client)
brew install minio/stable/mc  # macOS
# or download from https://min.io/download

# Configure
mc alias set local http://localhost:9000 minioadmin minioadmin

# Create bucket
mc mb local/retrosync-saves

# Verify
mc ls local
```

### 4. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Initialize database
npx prisma db push

# (Optional) Seed database with test data
npx prisma db seed

# Start development server
npm run dev
```

Backend runs at: http://localhost:3000

**Hot Reload**: Enabled automatically with Next.js dev server

### 5. Python Client Setup

```bash
cd client

# Create virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows

# Install in development mode
pip install -e .

# Install development dependencies
pip install -r requirements-dev.txt  # if exists
```

### 6. IDE Setup

#### VS Code (Recommended)

Install extensions:
```json
{
  "recommendations": [
    "prisma.prisma",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "bradlc.vscode-tailwindcss"
  ]
}
```

Settings (`.vscode/settings.json`):
```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true
  },
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true
}
```

#### PyCharm

1. Open project
2. Configure Python interpreter (use venv)
3. Enable Prisma plugin (optional)

---

## Project Structure

```
retrosync/
├── backend/                    # Next.js backend
│   ├── prisma/
│   │   ├── schema.prisma       # Database schema
│   │   └── dev.db              # SQLite database (dev)
│   ├── src/
│   │   ├── app/
│   │   │   ├── api/            # API routes
│   │   │   │   ├── auth/       # Authentication endpoints
│   │   │   │   ├── devices/    # Device management
│   │   │   │   └── sync/       # Sync endpoints
│   │   │   ├── auth/           # Auth pages
│   │   │   ├── dashboard/      # Dashboard pages
│   │   │   ├── page.tsx        # Landing page
│   │   │   ├── layout.tsx      # Root layout
│   │   │   └── globals.css     # Global styles
│   │   ├── components/         # React components
│   │   │   └── AuthForm.tsx
│   │   └── lib/                # Utilities
│   │       ├── prisma.ts       # Prisma client
│   │       ├── s3.ts           # S3 operations
│   │       ├── auth.ts         # Auth utils
│   │       └── utils.ts        # Helper functions
│   ├── package.json
│   ├── tsconfig.json
│   ├── next.config.js
│   └── tailwind.config.js
│
├── client/                     # Python client
│   ├── retrosync/
│   │   ├── __init__.py
│   │   ├── config.py           # Configuration
│   │   ├── detect.py           # OS detection
│   │   ├── api_client.py       # API client
│   │   ├── s3_client.py        # S3 client
│   │   ├── watcher.py          # File watcher
│   │   ├── sync_engine.py      # Sync logic
│   │   ├── daemon.py           # Daemon process
│   │   ├── ui.py               # Terminal UI
│   │   └── scripts/
│   │       └── setup_wizard.py # Setup wizard
│   ├── tests/                  # Python tests
│   ├── setup.py                # Package config
│   ├── requirements.txt        # Dependencies
│   └── RetroSync.sh            # Shell launcher
│
├── miyoo-shell/                # Shell-only client
│   ├── daemon.sh               # Main daemon
│   ├── setup.sh                # Setup script
│   └── launch.sh               # Launcher
│
├── docs/                       # Documentation
│   ├── ARCHITECTURE.md         # Architecture docs
│   ├── API.md                  # API reference
│   └── DEVELOPER.md            # This file
│
├── docker-compose.yml          # MinIO setup
├── .env.example                # Environment template
├── .gitignore
└── README.md
```

---

## Development Workflow

### Branch Strategy

We use **Git Flow**:

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `hotfix/*` - Critical fixes for production

### Feature Development

```bash
# 1. Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/my-new-feature

# 2. Make changes, commit often
git add .
git commit -m "feat: add new sync algorithm"

# 3. Push to remote
git push -u origin feature/my-new-feature

# 4. Create Pull Request
# Go to GitHub and create PR from feature branch to develop
```

### Commit Message Convention

We follow **Conventional Commits**:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process, tooling changes

**Examples**:
```bash
git commit -m "feat(api): add batch sync log endpoint"
git commit -m "fix(client): resolve file watcher memory leak"
git commit -m "docs(api): update pairing code documentation"
git commit -m "test(sync): add conflict resolution tests"
```

### Code Style

#### TypeScript/JavaScript

**Formatter**: Prettier

```bash
# Backend
cd backend
npm run format        # Format code
npm run lint          # Lint code
npm run lint:fix      # Auto-fix lint issues
```

**Prettier config** (`.prettierrc`):
```json
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5"
}
```

**ESLint config** (`.eslintrc.json`):
```json
{
  "extends": "next/core-web-vitals",
  "rules": {
    "no-console": "warn",
    "prefer-const": "error"
  }
}
```

#### Python

**Formatter**: Black

```bash
# Client
cd client
black .               # Format code
pylint retrosync/     # Lint code
mypy retrosync/       # Type checking
```

**Black config** (`pyproject.toml`):
```toml
[tool.black]
line-length = 88
target-version = ['py39']
```

**Pylint config** (`.pylintrc`):
```ini
[MESSAGES CONTROL]
disable=C0111,C0103,R0913
```

### Running in Development

#### Backend

```bash
cd backend
npm run dev
```

Features:
- Hot reload on file changes
- TypeScript compilation
- Error overlay in browser
- API available at http://localhost:3000/api

#### Python Client

```bash
cd client

# Run setup wizard
python -m retrosync setup

# Run daemon (foreground for debugging)
python -m retrosync daemon --debug

# Run UI
python -m retrosync ui
```

#### Shell Client

```bash
cd miyoo-shell

# Run setup
./setup.sh

# Run daemon (foreground)
./daemon.sh

# Test on device
scp -r miyoo-shell/ root@<device-ip>:/mnt/SDCARD/App/RetroSync/
```

### Database Migrations

When changing Prisma schema:

```bash
cd backend

# 1. Edit prisma/schema.prisma

# 2. Create migration (production)
npx prisma migrate dev --name add_new_field

# OR for rapid prototyping (dev only)
npx prisma db push

# 3. Regenerate Prisma client
npx prisma generate

# 4. Restart dev server
```

**View database**:
```bash
npx prisma studio
# Opens GUI at http://localhost:5555
```

---

## Testing

### Backend Tests

#### Unit Tests (Jest)

```bash
cd backend

# Run all tests
npm test

# Run specific test
npm test -- auth.test.ts

# Run with coverage
npm test -- --coverage

# Watch mode
npm test -- --watch
```

**Example test** (`src/lib/__tests__/auth.test.ts`):
```typescript
import { hashPassword, verifyPassword } from '../auth'

describe('Auth utilities', () => {
  it('should hash password correctly', async () => {
    const password = 'testPassword123'
    const hash = await hashPassword(password)
    expect(hash).not.toBe(password)
    expect(hash.length).toBeGreaterThan(0)
  })

  it('should verify password correctly', async () => {
    const password = 'testPassword123'
    const hash = await hashPassword(password)
    const isValid = await verifyPassword(password, hash)
    expect(isValid).toBe(true)
  })
})
```

#### Integration Tests (Supertest)

```bash
npm run test:integration
```

**Example** (`src/app/api/__tests__/auth.test.ts`):
```typescript
import request from 'supertest'
import { app } from '../../app'

describe('POST /api/auth/register', () => {
  it('should register new user', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'password123',
        name: 'Test User',
      })
      .expect(200)

    expect(response.body.success).toBe(true)
    expect(response.body.data.user.email).toBe('test@example.com')
    expect(response.body.data.token).toBeDefined()
  })
})
```

#### E2E Tests (Playwright)

```bash
npm run test:e2e
```

**Example** (`tests/e2e/pairing.spec.ts`):
```typescript
import { test, expect } from '@playwright/test'

test('device pairing flow', async ({ page }) => {
  // Register user
  await page.goto('http://localhost:3000/auth/register')
  await page.fill('[name=email]', 'test@example.com')
  await page.fill('[name=password]', 'password123')
  await page.click('button[type=submit]')

  // Generate pairing code
  await page.goto('http://localhost:3000/dashboard')
  await page.click('text=Add Device')
  const code = await page.locator('.pairing-code').textContent()

  expect(code).toMatch(/\d{6}/)
})
```

### Python Client Tests

#### Unit Tests (pytest)

```bash
cd client

# Run all tests
pytest

# Run specific test
pytest tests/test_sync_engine.py

# Run with coverage
pytest --cov=retrosync --cov-report=html

# Watch mode (pytest-watch)
ptw
```

**Example test** (`tests/test_sync_engine.py`):
```python
import pytest
from retrosync.sync_engine import SyncEngine
from retrosync.s3_client import S3Client
from retrosync.api_client import APIClient

@pytest.fixture
def sync_engine():
    s3_client = S3Client(...)
    api_client = APIClient(...)
    return SyncEngine(s3_client, api_client, 'device-id', ['/tmp/saves'])

def test_upload_file(sync_engine, tmp_path):
    # Create test file
    test_file = tmp_path / "test.sav"
    test_file.write_bytes(b"test save data")
    
    # Upload
    result = sync_engine.upload_file(str(test_file))
    
    assert result is True
```

#### Integration Tests

```bash
# Requires backend running
pytest tests/integration/
```

### Manual Testing

#### API Testing with Postman

Import collection: `docs/RetroSync.postman_collection.json`

**Or use cURL**:

```bash
# Register user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Create pairing code
curl -X POST http://localhost:3000/api/devices/create-pairing-code \
  -H "Authorization: Bearer <token>"

# Pair device
curl -X POST http://localhost:3000/api/devices/pair \
  -H "Content-Type: application/json" \
  -d '{"code":"123456","deviceName":"Test Device","deviceType":"linux"}'
```

#### Client Testing

**Test file sync**:

```bash
# 1. Start client daemon
cd client
python -m retrosync daemon --debug

# 2. In another terminal, create test save file
mkdir -p ~/retrosync-test/saves
echo "test save data" > ~/retrosync-test/saves/test.sav

# 3. Watch logs for upload event
# Should see: "Uploading test.sav..."

# 4. Check MinIO console
# http://localhost:9001
# File should appear in bucket
```

### Test Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Backend API | 80%+ |
| Backend Utils | 90%+ |
| Python Client | 70%+ |
| Integration | 60%+ |

---

## Building & Packaging

### Backend Build

```bash
cd backend

# Production build
npm run build

# Output: .next/ directory

# Start production server
npm start
```

### Python Client Package

```bash
cd client

# Build distribution packages
python setup.py sdist bdist_wheel

# Output: dist/retrosync-<version>.tar.gz

# Test installation
pip install dist/retrosync-*.tar.gz
```

### Shell Client Package

```bash
cd miyoo-shell

# Create package for Miyoo
zip -r RetroSync-miyoo.zip .

# Create package for Anbernic
zip -r RetroSync-anbernic.zip .
```

### Docker Images

#### Backend Docker Image

```bash
cd backend

# Build
docker build -t retrosync-backend:latest .

# Test locally
docker run -p 3000:3000 \
  -e DATABASE_URL="file:/data/retrosync.db" \
  -e JWT_SECRET="secret" \
  retrosync-backend:latest
```

**Dockerfile**:
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

RUN npx prisma generate
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
```

#### Full Stack Docker Compose

Already configured in `docker-compose.yml`:

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild
docker-compose build --no-cache
```

---

## Deployment

### Local/Self-Hosted (Docker Compose)

**Recommended for**: Home servers, NAS devices

```bash
# 1. Clone repository
git clone https://github.com/yourusername/retrosync.git
cd retrosync

# 2. Configure environment
cp .env.example .env
# Edit .env with production values

# 3. Start services
docker-compose up -d

# 4. Check status
docker-compose ps

# 5. View logs
docker-compose logs -f backend
```

**Access**:
- Dashboard: http://<server-ip>:3000
- MinIO Console: http://<server-ip>:9001

**Persistence**:
- Database: `backend_data` volume
- S3 Files: `minio_data` volume

**Backup**:
```bash
# Backup database
docker cp retrosync-backend:/data/retrosync.db ./backup/

# Backup MinIO data
docker run --rm -v minio_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/minio-backup.tar.gz /data
```

### VPS Deployment (DigitalOcean, Linode, etc.)

**Requirements**:
- Ubuntu 22.04 LTS
- 2GB RAM minimum
- 20GB storage minimum

#### Setup Script

```bash
#!/bin/bash
# deploy.sh

set -e

echo "Setting up RetroSync..."

# Update system
sudo apt update
sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone repository
git clone https://github.com/yourusername/retrosync.git
cd retrosync

# Configure environment
cp .env.example .env
nano .env  # Edit with your values

# Start services
docker-compose up -d

echo "RetroSync deployed! Access at http://$(curl -s ifconfig.me):3000"
```

Run:
```bash
chmod +x deploy.sh
./deploy.sh
```

#### NGINX Reverse Proxy

```nginx
# /etc/nginx/sites-available/retrosync

server {
    listen 80;
    server_name retrosync.example.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/retrosync /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### SSL with Let's Encrypt

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d retrosync.example.com

# Auto-renewal (cron)
sudo crontab -e
# Add: 0 0 * * * certbot renew --quiet
```

### Cloud Deployment (AWS, GCP, Azure)

#### AWS Elastic Beanstalk

```bash
# Install EB CLI
pip install awsebcli

# Initialize
cd backend
eb init -p node.js-18 retrosync

# Create environment
eb create retrosync-prod

# Deploy
eb deploy
```

#### Kubernetes

**Deployment manifest** (`k8s/backend-deployment.yaml`):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: retrosync-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: retrosync-backend
  template:
    metadata:
      labels:
        app: retrosync-backend
    spec:
      containers:
      - name: backend
        image: retrosync/backend:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: retrosync-secrets
              key: database-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: retrosync-secrets
              key: jwt-secret
---
apiVersion: v1
kind: Service
metadata:
  name: retrosync-backend
spec:
  selector:
    app: retrosync-backend
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

Deploy:
```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl get services
```

### Production Checklist

- [ ] Change default passwords in `.env`
- [ ] Generate strong JWT secret
- [ ] Enable HTTPS/TLS
- [ ] Configure firewall (allow only 80, 443)
- [ ] Set up database backups
- [ ] Configure monitoring (e.g., Prometheus)
- [ ] Set up logging (e.g., ELK stack)
- [ ] Enable rate limiting
- [ ] Configure CDN for static assets
- [ ] Set up error tracking (e.g., Sentry)
- [ ] Document disaster recovery plan
- [ ] Set up alerting (e.g., PagerDuty)

---

## Contributing

We welcome contributions! Here's how to get started:

### 1. Find an Issue

- Browse [open issues](https://github.com/yourusername/retrosync/issues)
- Look for `good first issue` label for beginners
- Comment on the issue to claim it

### 2. Fork & Clone

```bash
# Fork on GitHub, then:
git clone https://github.com/yourusername/retrosync.git
cd retrosync
git remote add upstream https://github.com/original/retrosync.git
```

### 3. Create Branch

```bash
git checkout develop
git checkout -b feature/your-feature-name
```

### 4. Make Changes

- Write code
- Add tests
- Update documentation
- Follow code style guidelines

### 5. Test

```bash
# Backend
cd backend
npm test
npm run lint

# Python
cd client
pytest
black .
pylint retrosync/
```

### 6. Commit

```bash
git add .
git commit -m "feat: add new feature"
```

Follow [Conventional Commits](#commit-message-convention).

### 7. Push & Pull Request

```bash
git push origin feature/your-feature-name
```

Create Pull Request on GitHub:
- Target: `develop` branch
- Fill out PR template
- Link related issue
- Request review

### Pull Request Guidelines

**Title**: Use conventional commit format
```
feat(api): add batch sync endpoint
fix(client): resolve memory leak
docs(readme): update installation instructions
```

**Description**: Include:
- What: Summary of changes
- Why: Motivation and context
- How: Technical approach
- Testing: How to test changes
- Screenshots: If UI changes

**Example**:
```markdown
## What
Adds batch sync log endpoint to reduce API calls.

## Why
Devices currently make 1 API call per file synced. This creates excessive load.

## How
- New endpoint: POST /api/sync/log/batch
- Accepts array of log entries
- Validates and inserts in single transaction

## Testing
```bash
npm test -- batch.test.ts
```

## Screenshots
N/A
```

### Code Review Process

1. **Automated Checks**: CI/CD runs tests, linting
2. **Review**: Maintainer reviews code
3. **Changes Requested**: Address feedback
4. **Approval**: Maintainer approves
5. **Merge**: Squash and merge to develop

### Contributor License Agreement

By contributing, you agree:
- Code is licensed under MIT
- You have rights to contribute
- No confidential/proprietary code

---

## Troubleshooting

### Backend Issues

#### "Port 3000 already in use"

```bash
# Find process
lsof -i :3000

# Kill process
kill -9 <PID>

# Or use different port
PORT=3001 npm run dev
```

#### "Prisma Client not generated"

```bash
cd backend
npx prisma generate
```

#### "Database locked" (SQLite)

```bash
# Stop all backend processes
pkill -f "npm run dev"

# Delete database lock
rm backend/prisma/dev.db-journal

# Restart
npm run dev
```

### Client Issues

#### "Module not found: retrosync"

```bash
# Reinstall in editable mode
cd client
pip install -e .
```

#### "Permission denied" on save directory

```bash
# Fix permissions (Linux/Mac)
chmod -R 755 ~/retrosync-saves

# Or run with sudo (not recommended)
sudo python -m retrosync daemon
```

#### "Connection refused to API"

```bash
# Check backend is running
curl http://localhost:3000/api/health

# Check firewall
sudo ufw status

# Check API URL in config
cat ~/.retrosync/config.json
```

### MinIO Issues

#### "Bucket not found"

```bash
# Create bucket manually
mc alias set local http://localhost:9000 minioadmin minioadmin
mc mb local/retrosync-saves
```

#### "Connection refused to MinIO"

```bash
# Check container
docker ps | grep minio

# Restart container
docker-compose restart minio

# Check logs
docker-compose logs minio
```

### Device-Specific Issues

#### Miyoo Flip

**Python not found**:
```bash
# Install Python on Spruce OS
# (Instructions specific to OS)
```

**Save directory not detected**:
```bash
# Check mount point
ls /mnt/SDCARD/Saves/

# Update config
nano ~/RetroSync/config.json
```

#### Anbernic RG35XX+

**muOS save path**:
```bash
# Check muOS version
cat /opt/muos/version

# Common paths:
# /mnt/mmc/MUOS/save/
# /mnt/sdcard/MUOS/save/
```

### Getting Help

1. **Check Documentation**: Docs in `/docs` folder
2. **Search Issues**: https://github.com/yourusername/retrosync/issues
3. **Ask Community**: Discord server (link)
4. **Create Issue**: Provide:
   - OS and version
   - RetroSync version
   - Error messages
   - Steps to reproduce

---

## FAQ

**Q: Can I use PostgreSQL instead of SQLite?**

A: Yes! Update `DATABASE_URL` in `.env`:
```env
DATABASE_URL="postgresql://user:password@localhost:5432/retrosync"
```

Then run:
```bash
npx prisma migrate dev
```

**Q: How do I reset my development environment?**

```bash
# Stop all services
docker-compose down -v

# Delete database
rm backend/prisma/dev.db

# Restart
docker-compose up -d
cd backend && npx prisma db push && npm run dev
```

**Q: Can I contribute without coding?**

Yes! Contributions welcome:
- Documentation improvements
- Bug reports
- Feature suggestions
- Testing on devices
- Translations (future)

**Q: How do I deploy to production?**

See [Deployment](#deployment) section.

**Q: Is there a roadmap?**

See [GitHub Projects](https://github.com/yourusername/retrosync/projects).

**Q: How do I update to the latest version?**

```bash
git pull origin main
cd backend && npm install && npx prisma migrate deploy
docker-compose pull
docker-compose up -d
```

---

## Additional Resources

### Documentation
- [Architecture Overview](./ARCHITECTURE.md)
- [API Reference](./API.md)
- [Quick Start Guide](./README.md)

### External Resources
- [Next.js Docs](https://nextjs.org/docs)
- [Prisma Docs](https://www.prisma.io/docs)
- [MinIO Docs](https://min.io/docs)
- [Python Packaging](https://packaging.python.org)

### Community
- GitHub Discussions: https://github.com/yourusername/retrosync/discussions
- Discord: (invite link)
- Twitter: @retrosync

---

**Developer Guide Version**: 1.0  
**Last Updated**: 2024-01-30  
**Maintained By**: RetroSync Development Team

**Happy coding! 🚀**
