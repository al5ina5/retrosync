# RetroSync Architecture Documentation

## Table of Contents
- [System Overview](#system-overview)
- [High-Level Architecture](#high-level-architecture)
- [Components](#components)
- [Data Flow](#data-flow)
- [Database Schema](#database-schema)
- [API Endpoints](#api-endpoints)
- [Authentication & Authorization](#authentication--authorization)
- [File Synchronization Mechanics](#file-synchronization-mechanics)
- [Storage Structure](#storage-structure)
- [Technology Stack](#technology-stack)

---

## System Overview

RetroSync is a **cloud-based save file synchronization service** for retro gaming handhelds and PCs. It enables users to seamlessly sync their game saves across multiple devices including Anbernic RG35XX+, Miyoo Flip, and desktop computers.

### Key Features
- **Device Pairing**: Simple 6-digit code pairing system
- **Auto-Detection**: Automatically detects device type and save file locations
- **Real-Time Sync**: File changes trigger immediate uploads
- **Cross-Platform**: Supports multiple handheld OSes and desktop platforms
- **Local-First**: Can be self-hosted with Docker Compose
- **Conflict Resolution**: Last-write-wins strategy for conflicting changes

### Design Principles
1. **Local-First Development**: No external cloud dependencies required
2. **Simplicity**: Easy setup and minimal user configuration
3. **Privacy**: Self-hosted option keeps data under user control
4. **Reliability**: Robust file watching and retry mechanisms
5. **Extensibility**: Modular design supports adding new platforms

---

## High-Level Architecture

RetroSync follows a **client-server architecture** with S3-compatible object storage:

```
┌─────────────────────────────────────────────────────────────────┐
│                         RetroSync System                         │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Device 1   │     │   Device 2   │     │   Device N   │
│  (Anbernic)  │     │   (Miyoo)    │     │     (PC)     │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       │    File Watcher    │    File Watcher    │    File Watcher
       │    API Client      │    API Client      │    API Client
       │    S3 Client       │    S3 Client       │    S3 Client
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                    ┌───────▼────────┐
                    │   HTTPS/REST   │
                    └───────┬────────┘
                            │
              ┌─────────────▼─────────────┐
              │     Next.js Backend       │
              │  ┌─────────────────────┐  │
              │  │   API Routes        │  │
              │  │  - Auth             │  │
              │  │  - Devices          │  │
              │  │  - Sync             │  │
              │  └─────────┬───────────┘  │
              │            │              │
              │  ┌─────────▼───────────┐  │
              │  │   Business Logic    │  │
              │  │  - Auth Utils       │  │
              │  │  - S3 Client        │  │
              │  │  - Validation       │  │
              │  └─────────┬───────────┘  │
              │            │              │
              │  ┌─────────▼───────────┐  │
              │  │  Prisma ORM         │  │
              │  └─────────┬───────────┘  │
              └────────────┼──────────────┘
                           │
              ┌────────────▼──────────────┐
              │  SQLite Database          │
              │  - Users                  │
              │  - Devices                │
              │  - PairingCodes           │
              │  - SyncLogs               │
              └───────────────────────────┘

              ┌───────────────────────────┐
              │   MinIO S3 Storage        │
              │  - Save Files (Blobs)     │
              │  - Metadata               │
              └───────────────────────────┘

              ┌───────────────────────────┐
              │   Web Dashboard           │
              │  - User Registration      │
              │  - Device Management      │
              │  - Pairing Codes          │
              │  - Sync Activity          │
              └───────────────────────────┘
```

### Architecture Layers

1. **Client Layer**: Python/Shell clients running on devices
2. **API Layer**: Next.js REST API for device communication
3. **Business Logic Layer**: Authentication, validation, S3 operations
4. **Data Layer**: SQLite database for metadata
5. **Storage Layer**: MinIO for actual save files
6. **Web Layer**: React frontend for user management

---

## Components

### 1. Backend Server (Next.js)

**Location**: `backend/`

**Responsibilities**:
- Serve REST API for device operations
- Handle user authentication (JWT)
- Manage device pairing process
- Coordinate file synchronization
- Log sync events
- Serve web dashboard

**Key Files**:
- `src/app/api/auth/` - Authentication endpoints
- `src/app/api/devices/` - Device pairing and management
- `src/app/api/sync/` - Synchronization endpoints
- `src/lib/prisma.ts` - Database client
- `src/lib/s3.ts` - S3 operations
- `src/lib/auth.ts` - JWT and API key utilities

**Technology**:
- Next.js 14 (React framework with API routes)
- Prisma ORM (type-safe database access)
- JWT for authentication
- Zod for validation

---

### 2. Python Client

**Location**: `client/retrosync/`

**Responsibilities**:
- Auto-detect device type and save locations
- Watch save directories for changes
- Upload changed files to S3
- Download new files from S3
- Resolve conflicts (last-write-wins)
- Send heartbeats to server
- Log sync activity

**Key Modules**:
- `config.py` - Configuration management
- `detect.py` - OS and device type detection
- `api_client.py` - REST API communication
- `s3_client.py` - S3 file operations
- `watcher.py` - File system monitoring (watchdog)
- `sync_engine.py` - Sync orchestration
- `daemon.py` - Background daemon process
- `ui.py` - Terminal user interface

**Technology**:
- Python 3.9+
- watchdog (file system events)
- boto3 (S3 client)
- requests (HTTP client)

---

### 3. Shell-Only Client (Miyoo/Minimal)

**Location**: `miyoo-shell/`

**Responsibilities**:
- Provide lightweight alternative for devices without Python
- Monitor save directories using shell scripts
- Upload/download via curl
- Send heartbeats

**Key Files**:
- `daemon.sh` - Main sync loop
- `setup.sh` - Device setup wizard
- `launch.sh` - Launcher script

**Technology**:
- POSIX shell scripts
- curl for HTTP
- Standard Unix utilities (find, grep, stat)

---

### 4. Lua/LÖVE Client

**Location**: `main.lua`, `conf.lua`

**Responsibilities**:
- Provide GUI for Miyoo devices with LÖVE support
- Visual pairing code entry
- Status display
- Same sync logic as Python client

**Technology**:
- LÖVE 2D framework
- Lua 5.1+

---

### 5. MinIO Storage

**Deployment**: Docker container

**Responsibilities**:
- Store save file blobs
- Provide S3-compatible API
- Handle bucket management
- Support presigned URLs

**Configuration**:
- Port 9000: S3 API
- Port 9001: Web console
- Default credentials: minioadmin/minioadmin
- Bucket: `retrosync-saves`

---

### 6. Web Dashboard

**Location**: `backend/src/app/`

**Responsibilities**:
- User registration and login
- Device management
- Pairing code generation (with QR code)
- Sync activity monitoring
- Real-time status display

**Key Pages**:
- `/` - Landing page
- `/auth/login` - Login page
- `/auth/register` - Registration page
- `/dashboard` - Main dashboard
- `/dashboard/devices` - Device management

**Technology**:
- React with TypeScript
- Next.js App Router
- Tailwind CSS (styling)
- QRCode.js (pairing QR codes)

---

## Data Flow

### 1. User Registration & Device Pairing

```
User → Browser → POST /api/auth/register
                    ↓
                Creates User in DB
                    ↓
                Returns JWT token
                    ↓
User → Browser → POST /api/devices/create-pairing-code
                    ↓
                Creates 6-digit code (expires in 15 min)
                    ↓
                Returns code + QR code
                    ↓
Device → Client → POST /api/devices/pair (with code)
                    ↓
                Validates code
                    ↓
                Creates Device in DB
                Generates API key
                    ↓
                Returns API key + S3 credentials
                    ↓
Device → Saves credentials to config.json
```

### 2. File Upload (Device → Cloud → Other Devices)

```
Device 1 (Save File Changed)
    ↓
File Watcher detects change (inotify/polling)
    ↓
Calculate file hash (SHA256)
    ↓
Compare with last known hash
    ↓
If changed:
    ↓
Extract emulator type and game ID from path
    ↓
Upload to S3:
  Key: {user_id}/{device_id}/{emulator}/{game_id}/{filename}
    ↓
POST /api/sync/log (record upload event)
    ↓
MinIO stores blob
    ↓
Other devices (Device 2, 3, ...) poll for updates
    ↓
POST /api/sync/heartbeat (every minute)
GET /api/sync/files (every 5 minutes)
    ↓
Find new files from other devices
    ↓
Compare remote vs local modification time
    ↓
If remote is newer:
    ↓
Download from S3
    ↓
Save to local save directory
    ↓
POST /api/sync/log (record download event)
```

### 3. Conflict Resolution

```
Device 1 modifies file at 10:00:00
Device 2 modifies same file at 10:00:05 (offline)
    ↓
Device 1 uploads at 10:00:01
    ↓
Device 2 comes online, attempts upload at 10:00:10
    ↓
Sync Engine detects conflict:
  - Local file timestamp: 10:00:05
  - Remote file timestamp: 10:00:01
    ↓
Last-write-wins: Device 2's file is newer
    ↓
Device 2 uploads, overwrites Device 1's version
    ↓
POST /api/sync/log (action: "conflict", resolved by timestamp)
    ↓
Device 1 polls for updates
    ↓
Detects remote file is newer
    ↓
Downloads Device 2's version
```

---

## Database Schema

RetroSync uses **Prisma ORM** with **SQLite** (production-ready PostgreSQL migration available).

### Entity Relationship Diagram

```
┌─────────────────┐
│      User       │
├─────────────────┤
│ id (PK)         │
│ email (UNIQUE)  │
│ passwordHash    │
│ name            │
│ subscriptionTier│
│ createdAt       │
│ updatedAt       │
└────────┬────────┘
         │
         │ 1:N
         │
    ┌────▼──────────────┐
    │      Device       │
    ├───────────────────┤
    │ id (PK)           │
    │ userId (FK)       │
    │ name              │
    │ deviceType        │
    │ apiKey (UNIQUE)   │
    │ lastSyncAt        │
    │ isActive          │
    │ createdAt         │
    │ updatedAt         │
    └────────┬──────────┘
             │
             │ 1:N
             │
        ┌────▼──────────┐
        │   SyncLog     │
        ├───────────────┤
        │ id (PK)       │
        │ deviceId (FK) │
        │ action        │
        │ filePath      │
        │ fileSize      │
        │ status        │
        │ errorMsg      │
        │ metadata      │
        │ createdAt     │
        └───────────────┘

┌─────────────────┐
│      User       │
└────────┬────────┘
         │
         │ 1:N
         │
    ┌────▼──────────────┐
    │   PairingCode     │
    ├───────────────────┤
    │ id (PK)           │
    │ code (UNIQUE)     │
    │ userId (FK)       │
    │ expiresAt         │
    │ used              │
    │ usedAt            │
    │ deviceId          │
    │ createdAt         │
    └───────────────────┘
```

### Schema Definition

**File**: `backend/prisma/schema.prisma`

#### User Model
```prisma
model User {
  id                String        @id @default(uuid())
  email             String        @unique
  passwordHash      String
  name              String?
  subscriptionTier  String        @default("free")
  createdAt         DateTime      @default(now())
  updatedAt         DateTime      @updatedAt

  devices           Device[]
  pairingCodes      PairingCode[]
}
```

**Fields**:
- `id`: UUID primary key
- `email`: Unique email address
- `passwordHash`: bcrypt hash of password
- `name`: Optional display name
- `subscriptionTier`: "free", "pro", or "enterprise"
- Timestamps: `createdAt`, `updatedAt`

#### Device Model
```prisma
model Device {
  id           String    @id @default(uuid())
  userId       String
  name         String
  deviceType   String    // rg35xx, miyoo_flip, windows, mac, linux
  apiKey       String    @unique
  lastSyncAt   DateTime?
  isActive     Boolean   @default(true)
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt

  user         User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  syncLogs     SyncLog[]

  @@index([userId])
  @@index([apiKey])
}
```

**Fields**:
- `id`: UUID primary key
- `userId`: Foreign key to User
- `name`: Device display name (e.g., "My Anbernic RG35XX+")
- `deviceType`: One of: rg35xx, miyoo_flip, windows, mac, linux, other
- `apiKey`: 64-character hex string for device authentication
- `lastSyncAt`: Last heartbeat timestamp
- `isActive`: Whether device is currently active

#### PairingCode Model
```prisma
model PairingCode {
  id         String    @id @default(uuid())
  code       String    @unique
  userId     String
  expiresAt  DateTime
  used       Boolean   @default(false)
  usedAt     DateTime?
  deviceId   String?
  createdAt  DateTime  @default(now())

  user       User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([code])
  @@index([userId])
}
```

**Fields**:
- `id`: UUID primary key
- `code`: 6-digit pairing code (e.g., "123456")
- `userId`: Foreign key to User
- `expiresAt`: Code expiration timestamp (15 minutes from creation)
- `used`: Whether code has been used
- `usedAt`: When code was used
- `deviceId`: Device that used this code

#### SyncLog Model
```prisma
model SyncLog {
  id         String    @id @default(uuid())
  deviceId   String
  action     String    // upload, download, delete, conflict
  filePath   String
  fileSize   Int?
  status     String    // success, failed, pending
  errorMsg   String?
  metadata   String?   // JSON string for additional data
  createdAt  DateTime  @default(now())

  device     Device    @relation(fields: [deviceId], references: [id], onDelete: Cascade)

  @@index([deviceId])
  @@index([createdAt])
}
```

**Fields**:
- `id`: UUID primary key
- `deviceId`: Foreign key to Device
- `action`: Type of sync event (upload, download, delete, conflict)
- `filePath`: Path to synced file
- `fileSize`: File size in bytes
- `status`: success, failed, or pending
- `errorMsg`: Error message if failed
- `metadata`: JSON string for additional context

---

## API Endpoints

### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login existing user |

### Device Management Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/devices/create-pairing-code` | Generate 6-digit pairing code |
| POST | `/api/devices/pair` | Exchange pairing code for API key |
| GET | `/api/devices` | List user's devices |
| DELETE | `/api/devices` | Remove device |

### Synchronization Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/sync/heartbeat` | Device check-in |
| GET | `/api/sync/files` | List available save files |
| POST | `/api/sync/log` | Record sync event |
| GET | `/api/sync/log` | Retrieve sync history |

See [API.md](./API.md) for detailed request/response formats.

---

## Authentication & Authorization

### User Authentication (JWT)

**Flow**:
1. User registers with email/password → `POST /api/auth/register`
2. Server hashes password with bcrypt (10 rounds)
3. Server generates JWT token with payload:
   ```json
   {
     "userId": "uuid",
     "email": "user@example.com",
     "type": "user",
     "iat": 1234567890,
     "exp": 1237159890
   }
   ```
4. Token expires in 30 days
5. Client includes token in Authorization header: `Bearer <token>`

**Implementation**:
- Library: `jsonwebtoken`
- Secret: `JWT_SECRET` environment variable
- Algorithm: HS256

### Device Authentication (API Key)

**Flow**:
1. Device pairs with 6-digit code → `POST /api/devices/pair`
2. Server validates code (not used, not expired)
3. Server generates 64-character hex API key (crypto.randomBytes)
4. API key stored in Device table (unique constraint)
5. Device includes API key in requests: `X-API-Key: <key>`

**Security**:
- API keys are 256-bit random values
- No expiration (revoked by deleting device)
- Scoped to single device

### Pairing Code Security

**Properties**:
- 6-digit code (100,000 - 999,999)
- Expires after 15 minutes
- Single-use only
- Includes QR code for easy scanning

**Generation**:
```typescript
function generatePairingCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString()
}
```

### Authorization Matrix

| Endpoint | Authentication | Authorization |
|----------|---------------|---------------|
| `/api/auth/register` | None | Public |
| `/api/auth/login` | None | Public |
| `/api/devices/create-pairing-code` | JWT | User must own token |
| `/api/devices/pair` | None | Valid pairing code |
| `/api/devices` (GET) | JWT | User can list own devices |
| `/api/devices` (DELETE) | JWT | User can delete own devices |
| `/api/sync/heartbeat` | API Key | Device must exist |
| `/api/sync/files` | API Key | Device must exist |
| `/api/sync/log` | API Key | Device must exist |

---

## File Synchronization Mechanics

### 1. File Watching

**Python Client** (Linux, Mac, Windows):
```python
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class SaveFileHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.is_directory:
            return
        if is_save_file(event.src_path):
            debounce_and_upload(event.src_path)
```

**Features**:
- Uses `watchdog` library (inotify on Linux, FSEvents on Mac, ReadDirectoryChangesW on Windows)
- 2-second debounce to avoid multiple uploads during rapid saves
- Filters by save file extensions (.srm, .sav, .state, etc.)

**Shell Client** (Miyoo/resource-constrained):
- Polls save directory every 5 seconds
- Compares file modification timestamps
- Uploads only changed files

### 2. Upload Process

```python
def upload_file(file_path: str):
    # 1. Detect emulator and game from path
    emulator, game_id = detect_emulator_from_path(file_path)
    
    # 2. Calculate file hash (SHA256)
    file_hash = calculate_hash(file_path)
    
    # 3. Check if upload needed
    if file_hash == cached_hash:
        return  # No change
    
    # 4. Build S3 key
    key = f"{user_id}/{device_id}/{emulator}/{game_id}/{filename}"
    
    # 5. Upload to S3
    s3_client.upload_file(
        Bucket='retrosync-saves',
        Key=key,
        Body=open(file_path, 'rb')
    )
    
    # 6. Update hash cache
    save_hash(file_path, file_hash)
    
    # 7. Log event
    api_client.log_sync_event(
        action='upload',
        file_path=file_path,
        file_size=os.path.getsize(file_path),
        status='success'
    )
```

### 3. Download Process

```python
def sync_from_cloud():
    # 1. List all files in user's S3 bucket
    files = s3_client.list_objects_v2(
        Bucket='retrosync-saves',
        Prefix=f"{user_id}/"
    )
    
    # 2. For each file from other devices
    for obj in files:
        key = obj['Key']
        if device_id in key:
            continue  # Skip own uploads
        
        # 3. Parse key
        parts = key.split('/')
        emulator, game_id, filename = parts[-3:]
        
        # 4. Find local path
        local_path = find_local_path(emulator, game_id, filename)
        
        # 5. Compare timestamps
        remote_mtime = obj['LastModified']
        local_mtime = get_file_mtime(local_path)
        
        if remote_mtime > local_mtime:
            # 6. Download newer file
            s3_client.download_file(
                Bucket='retrosync-saves',
                Key=key,
                Filename=local_path
            )
            
            # 7. Log event
            api_client.log_sync_event(
                action='download',
                file_path=local_path,
                status='success'
            )
```

### 4. Conflict Resolution

**Strategy**: Last-Write-Wins

```python
def resolve_conflict(local_path: str, remote_key: str):
    # Get timestamps
    local_mtime = datetime.fromtimestamp(
        os.path.getmtime(local_path)
    )
    
    remote_metadata = s3_client.head_object(
        Bucket='retrosync-saves',
        Key=remote_key
    )
    remote_mtime = remote_metadata['LastModified']
    
    # Compare and resolve
    if local_mtime > remote_mtime:
        # Local is newer, upload
        upload_file(local_path)
    else:
        # Remote is newer, download
        download_file(remote_key, local_path)
    
    # Log conflict
    api_client.log_sync_event(
        action='conflict',
        file_path=local_path,
        status='success',
        metadata=json.dumps({
            'local_mtime': local_mtime.isoformat(),
            'remote_mtime': remote_mtime.isoformat(),
            'winner': 'local' if local_mtime > remote_mtime else 'remote'
        })
    )
```

### 5. Emulator and Game Detection

**Path Patterns**:
```python
EMULATOR_PATTERNS = {
    'nes': ['nes', 'fceux', 'nestopia'],
    'snes': ['snes', 'snes9x', 'zsnes'],
    'gba': ['gba', 'visualboyadvance', 'mgba'],
    'gb': ['gb', 'gameboy'],
    'genesis': ['genesis', 'megadrive', 'gens'],
    'n64': ['n64', 'mupen64'],
    'ps1': ['psx', 'ps1', 'pcsx'],
}

def detect_emulator_from_path(path: str) -> tuple[str, str]:
    """
    Detect emulator and game from file path
    
    Example:
      /mnt/SDCARD/Saves/GBA/Pokemon.sav
      → emulator: 'gba', game_id: 'Pokemon'
    """
    parts = Path(path).parts
    
    # Check each part for emulator name
    for part in parts:
        part_lower = part.lower()
        for emu, patterns in EMULATOR_PATTERNS.items():
            if any(p in part_lower for p in patterns):
                # Game ID is filename without extension
                game_id = Path(path).stem
                return emu, game_id
    
    # Fallback: use parent directory as emulator
    return parts[-2], Path(path).stem
```

### 6. Heartbeat & Health

**Purpose**: 
- Keep device connection alive
- Update last sync timestamp
- Signal device is active

**Frequency**: Every 60 seconds

**Implementation**:
```python
def heartbeat_loop():
    while True:
        try:
            api_client.heartbeat()
            time.sleep(60)
        except Exception as e:
            logger.error(f"Heartbeat failed: {e}")
            time.sleep(5)  # Retry faster on error
```

### 7. Sync Intervals

| Event | Timing |
|-------|--------|
| File change detected | Immediate (2s debounce) |
| Poll for downloads | Every 5 minutes |
| Heartbeat | Every 60 seconds |
| Initial sync | On first run |

---

## Storage Structure

### S3 Bucket Organization

**Bucket Name**: `retrosync-saves`

**Key Format**:
```
{user_id}/{device_id}/{emulator_type}/{game_identifier}/{filename}
```

**Example**:
```
815486/                                    # User ID
  3e3944bc-3b0d-4f21-984d-1428522a1ada/   # Device 1 (Anbernic)
    gba/                                   # Emulator type
      pokemon_emerald/                     # Game identifier
        pokemon_emerald.sav                # Save file
        pokemon_emerald.st1                # Save state 1
      mario_kart/
        mario_kart.sav
    nes/
      super_mario/
        super_mario.srm
  91f07ca4-6e9d-45d0-8792-de4ad6d15d4d/   # Device 2 (Miyoo)
    gba/
      pokemon_emerald/
        pokemon_emerald.sav
```

### Metadata Storage

Each file can optionally include a metadata JSON file:

**Key**: `{user_id}/{device_id}/{emulator}/{game}/metadata.json`

**Content**:
```json
{
  "game_name": "Pokemon Emerald",
  "emulator": "mgba",
  "platform": "gba",
  "last_played": "2024-01-27T10:30:00Z",
  "play_time_hours": 45.5,
  "device_name": "My Anbernic RG35XX+"
}
```

### File Permissions

- **Read**: All devices belonging to the same user
- **Write**: Only the owning device
- **Delete**: Only via device API

### Storage Quotas (Future)

| Tier | Storage Limit | Max Devices |
|------|--------------|-------------|
| Free | 100 MB | 3 |
| Pro | 1 GB | 10 |
| Enterprise | Unlimited | Unlimited |

---

## Technology Stack

### Backend
- **Runtime**: Node.js 18+
- **Framework**: Next.js 14 (React + API routes)
- **ORM**: Prisma 5
- **Database**: SQLite (development), PostgreSQL (production)
- **Authentication**: JWT (jsonwebtoken), bcrypt
- **Validation**: Zod
- **S3 Client**: aws-sdk
- **QR Codes**: qrcode

### Storage
- **Object Storage**: MinIO (S3-compatible)
- **Deployment**: Docker Compose

### Python Client
- **Language**: Python 3.9+
- **File Watching**: watchdog
- **S3 Client**: boto3
- **HTTP Client**: requests
- **Logging**: Python logging module

### Shell Client
- **Shell**: POSIX sh (compatible with busybox)
- **HTTP**: curl
- **JSON Parsing**: grep, sed (basic parsing)

### Lua/LÖVE Client
- **Framework**: LÖVE 11.x
- **Language**: Lua 5.1
- **HTTP**: socket.http (LuaSocket)

### DevOps
- **Containerization**: Docker
- **Orchestration**: Docker Compose
- **Development**: Hot reload (Next.js dev server)

### Deployment Options
1. **Local Development**: Docker Compose on localhost
2. **Self-Hosted**: Docker Compose on VPS/NAS
3. **Cloud**: Kubernetes + Cloud SQL + Cloud Storage

---

## Security Considerations

### Current Implementation

1. **Password Security**:
   - bcrypt hashing with 10 rounds
   - Minimum 8 characters enforced

2. **API Key Security**:
   - 256-bit random keys
   - Unique per device
   - No expiration (revoke by deletion)

3. **Pairing Code Security**:
   - 6-digit codes (1 million possibilities)
   - 15-minute expiration
   - Single-use only

4. **Database**:
   - Parameterized queries (Prisma ORM)
   - SQL injection protection

### Recommended Production Enhancements

1. **HTTPS/TLS**: Enforce TLS for all API traffic
2. **Rate Limiting**: Prevent brute-force attacks on pairing codes
3. **File Encryption**: Encrypt save files at rest in S3
4. **Audit Logging**: Log all security events
5. **2FA**: Optional two-factor authentication
6. **API Key Rotation**: Periodic key rotation policy
7. **Input Sanitization**: Additional validation layers
8. **CORS**: Proper CORS configuration for web dashboard

---

## Scalability & Performance

### Current Limitations

- **SQLite**: Single-threaded writes
- **No Caching**: Every request hits database
- **No CDN**: Static assets served from origin
- **Polling**: Devices poll for updates instead of push

### Scaling Recommendations

1. **Database**:
   - Migrate to PostgreSQL
   - Add read replicas
   - Connection pooling (PgBouncer)

2. **Caching**:
   - Redis for session storage
   - Cache device credentials
   - Cache sync logs (recent)

3. **Storage**:
   - CloudFront CDN for S3
   - Multi-region replication
   - Lifecycle policies for old saves

4. **Real-Time Updates**:
   - WebSocket server for push notifications
   - Reduce polling frequency
   - Event-driven architecture (SQS/Kafka)

5. **API**:
   - Load balancer (NGINX/HAProxy)
   - Horizontal scaling (multiple backend instances)
   - Rate limiting (Redis)

### Performance Metrics

| Metric | Current | Target |
|--------|---------|--------|
| API Latency (p95) | ~50ms | <100ms |
| Upload Time (1MB) | ~2s | <5s |
| Download Time (1MB) | ~2s | <5s |
| Sync Delay | 5 min (poll) | <30s (push) |
| Max Concurrent Devices | ~100 | 10,000+ |

---

## Error Handling & Resilience

### Client-Side

1. **Network Failures**: Exponential backoff retry (1s, 2s, 4s, 8s, max 60s)
2. **File Conflicts**: Last-write-wins with logging
3. **Corrupt Files**: Skip and log, continue syncing
4. **Quota Exceeded**: Graceful error message, pause sync

### Server-Side

1. **Database Errors**: Transaction rollback, return 500
2. **S3 Failures**: Retry 3 times, return 502
3. **Invalid Requests**: Return 400 with validation errors
4. **Authentication Errors**: Return 401/403 with clear message

### Logging

- **Client**: Local log files (`~/.retrosync/retrosync.log`)
- **Server**: Console output (Docker logs)
- **S3**: Access logs (optional)

---

## Future Enhancements

### Planned Features

1. **File Versioning**: Keep history of save files
2. **Selective Sync**: Choose which games to sync
3. **Bandwidth Optimization**: Delta sync (rsync-style)
4. **Mobile Apps**: iOS/Android monitoring apps
5. **Cloud Providers**: AWS S3, Backblaze B2 support
6. **Encryption**: End-to-end encryption option
7. **Webhooks**: Notify external services of sync events
8. **Analytics**: Usage statistics and insights

### Platform Support

- [ ] Anbernic RG35XX (OnionOS)
- [ ] Steam Deck
- [ ] Nintendo Switch (homebrew)
- [ ] Android (RetroArch)
- [ ] iOS (RetroArch)

---

## Appendix

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Database connection string | `file:./dev.db` |
| `JWT_SECRET` | Secret for JWT signing | (required) |
| `MINIO_ENDPOINT` | MinIO endpoint URL | `http://localhost:9000` |
| `MINIO_ROOT_USER` | MinIO access key | `minioadmin` |
| `MINIO_ROOT_PASSWORD` | MinIO secret key | `minioadmin` |
| `MINIO_BUCKET` | S3 bucket name | `retrosync-saves` |
| `NEXT_PUBLIC_API_URL` | Public API URL for clients | `http://localhost:3000` |

### Save File Extensions

Supported save file extensions:
- `.srm` - SRAM save files
- `.sav` - Generic save files
- `.state` - Save states
- `.st`, `.st1`, `.st2`, etc. - Save state slots
- `.eep` - EEPROM saves
- `.fla` - Flash memory saves
- `.mpk` - N64 memory pak
- `.rtc` - Real-time clock saves
- `.dss` - DeSmuME save states
- `.dsv` - Nintendo DS saves
- `.sps` - SNES9x save states
- `.gci` - GameCube memory card
- `.raw` - Raw save data

### Device Type Codes

| Code | Device/Platform |
|------|-----------------|
| `rg35xx` | Anbernic RG35XX, RG35XX+ |
| `miyoo_flip` | Miyoo Flip |
| `miyoo_mini` | Miyoo Mini, Mini+ |
| `windows` | Windows PC |
| `mac` | macOS |
| `linux` | Linux PC |
| `other` | Other/Unknown |

---

**Document Version**: 1.0  
**Last Updated**: 2024-01-30  
**Maintained By**: RetroSync Development Team
