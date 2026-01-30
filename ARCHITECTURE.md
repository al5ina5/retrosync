# RetroSync Architecture Documentation

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [System Overview](#system-overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [API Reference](#api-reference)
6. [Data Storage](#data-storage)
7. [Security](#security)

---

## System Overview

RetroSync is a lightweight cloud sync service for retro gaming save files. It enables:

- **Automatic backup** of save files to cloud storage
- **Cross-device sync** between handhelds and PCs
- **Simple pairing** using 6-digit codes
- **Web dashboard** for account management

### Key Characteristics

| Aspect | Description |
|--------|-------------|
| **Architecture** | Client-Server (REST) |
| **Server** | Node.js single file (server.js) |
| **Storage** | MinIO (S3-compatible) + JSON file |
| **Auth** | Email/password for users, codes for devices |
| **Protocol** | HTTP/REST |
| **Port** | 4000 (configurable) |

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           RetroSync System                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐      HTTP (4000)      ┌──────────────┐                   │
│   │  Device  │◀────────────────────▶│   Server     │                   │
│   │  Client  │                      │  (Node.js)   │                   │
│   └──────────┘                      └──────┬───────┘                   │
│          │                                 │                            │
│          │              ┌──────────────────┼──────────────┐            │
│          │              │                  │              │            │
│          ▼              ▼                  ▼              ▼            │
│   ┌──────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────┐       │
│   │  Display │  │  Web UI      │  │  MinIO     │  │  Saves   │       │
│   │  / UI    │  │  (HTML/JS)   │  │  (S3)      │  │  Storage │       │
│   └──────────┘  └──────────────┘  └────────────┘  └──────────┘       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Server | Node.js (server.js) | HTTP API + Web UI |
| Storage | data.json | Users, devices, metadata |
| File Storage | MinIO | Save files (.srm, .state, etc.) |
| Client | Python/Lua/Shell | Device-side sync |

---

## Component Details

### 1. Server (server.js)

**Location:** `server.js`

A single-file Node.js HTTP server that handles:

- **User authentication** (register, login)
- **Device pairing** (register, claim, status)
- **Save upload/download** (REST API)
- **Web dashboard** (embedded HTML/JS)

**Key Features:**
- In-memory data with 5-second periodic save
- No database required (uses data.json)
- Embedded web UI (no separate frontend)
- CORS enabled for all origins

**Configuration:**
```javascript
const PORT = 4000;           // Server port
const HOST = '0.0.0.0';      // Listen on all interfaces
const DATA_DIR = '/home/alsinas/clawd/retrosync';  // Data directory
const DATA_FILE = `${DATA_DIR}/data.json`;
const SAVES_DIR = `${DATA_DIR}/saves`;
```

### 2. Data Storage (data.json)

**Location:** `/home/alsinas/clawd/retrosync/data.json`

```json
{
  "users": {
    "user@example.com": {
      "password_hash": "sha256_hash",
      "created_at": "2026-01-30T06:00:00.000Z"
    }
  },
  "devices": {
    "123456": {
      "status": "CONNECTED",
      "email": "user@example.com",
      "game_system": "miyoo-flip",
      "registered_at": "2026-01-30T06:00:00.000Z",
      "connected_at": "2026-01-30T06:05:00.000Z"
    }
  },
  "saves": {
    "123456": [
      {
        "id": "uuid",
        "filename": "game.srm",
        "game_name": "game.srm",
        "uploaded_at": "2026-01-30T06:10:00.000Z",
        "checksum": "md5_hash"
      }
    ]
  },
  "updated": "2026-01-30T06:15:00.000Z"
}
```

### 3. Save File Storage

**Location:** `/home/alsinas/clawd/retrosync/saves/{CODE}/`

Files are stored by device code:
```
saves/
└── 123456/
    ├── save-1.srm
    ├── save-2.srm
    └── game.state
```

### 4. MinIO (S3-Compatible Storage)

**Purpose:** Backup storage for save files (future use)

**Configuration:**
```
Endpoint: http://localhost:9000
Bucket: retrosync-saves
Access Key: minioadmin
Secret Key: minioadmin
```

**Currently:** Save files are stored locally in `saves/` directory  
**Future:** Will use MinIO for cloud backup

---

## Data Flow

### 1. Device Registration Flow

```
┌──────────┐                         ┌──────────┐
│  Device  │                         │  Server  │
└────┬─────┘                         └────┬─────┘
     │                                    │
     │  1. Generate 6-digit code          │
     │  (random 100000-999999)            │
     │                                    │
     │  2. POST /api/register             │
     │  {code: "123456", game_system: "miyoo-flip"} │
     │───────────────────────────────────▶│
     │                                    │
     │                                    │  3. Store device:
     │                                    │  status: "WAITING"
     │                                    │  email: null
     │                                    │
     │  4. {"success": true}              │
     │◀───────────────────────────────────│
     │                                    │
     │  5. Display code on screen         │
     │     "PAIRING CODE: 123456"         │
     │                                    │
```

### 2. Device Claiming Flow (User Action)

```
┌──────────┐                         ┌──────────┐
│  User    │                         │  Server  │
│ (Browser)│                         └────┬─────┘
└────┬─────┘                              │
     │                                    │
     │  1. GET http://SERVER:4000/        │
     │◀───────────────────────────────────│
     │  2. HTML page with login form      │
     │                                    │
     │  3. POST /api/auth/register        │
     │  {email: "user@example.com", password: "..."}
     │───────────────────────────────────▶│
     │                                    │
     │                                    │  4. Create user
     │                                    │  Store password hash
     │                                    │
     │  5. {"success": true}              │
     │◀───────────────────────────────────│
     │                                    │
     │  6. Enter device code "123456"     │
     │     POST /api/claim                │
     │     {code: "123456", email: "user@example.com"}
     │───────────────────────────────────▶│
     │                                    │
     │                                    │  7. Update device:
     │                                    │  status: "CONNECTED"
     │                                    │  email: "user@example.com"
     │                                    │  connected_at: now()
     │                                    │
     │  8. {"success": true}              │
     │◀───────────────────────────────────│
     │                                    │
```

### 3. Save Upload Flow

```
┌──────────┐                         ┌──────────┐
│  Device  │                         │  Server  │
└────┬─────┘                         └────┬─────┘
     │                                    │
     │  1. Game creates/changes save file │
     │                                    │
     │  2. Detect file change             │
     │  (watchdog or polling)             │
     │                                    │
     │  3. GET /api/status/123456         │
     │◀───────────────────────────────────│
     │  {"status": "CONNECTED", "email": "user@example.com"}
     │                                    │
     │  4. POST /api/saves/upload         │
     │  {code: "123456", filename: "game.srm", ...}
     │───────────────────────────────────▶│
     │                                    │
     │                                    │  5. Store save:
     │                                    │  - Create record in data.json
     │                                    │  - Save file to saves/123456/
     │                                    │
     │  6. {"success": true, save_id: "uuid"}
     │◀───────────────────────────────────│
     │                                    │
```

### 4. Cross-Device Sync Flow

```
┌──────────┐       ┌──────────┐       ┌──────────┐
│ Device A │       │  Server  │       │ Device B │
└────┬─────┘       └────┬─────┘       └────┬─────┘
     │                  │                  │
     │  1. Upload save  │                  │
     │─────────────────▶│                  │
     │                  │                  │
     │                  │  2. Poll         │
     │                  │◀─────────────────│
     │                  │  GET /api/saves  │
     │                  │                  │
     │                  │  3. Return saves │
     │                  │◀─────────────────│
     │                  │                  │
     │                  │                  │  4. Download save
     │                  │◀─────────────────│
     │                  │  GET /api/saves/download
     │                  │                  │
```

---

## API Reference

### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Create user account |
| POST | `/api/auth/login` | Login user |

### Device Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/register` | Register device with code |
| POST | `/api/claim` | Link device to user account |
| GET | `/api/status/{code}` | Get device status |
| GET | `/api/user/status` | Get user's devices and saves |

### Save Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/saves/upload` | Upload save file |
| GET | `/api/saves` | Get user's saves |

### Web Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Web dashboard (HTML) |
| GET | `/claim` | Device claiming page (HTML) |

---

### Request/Response Examples

#### Register User

**Request:**
```bash
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "mypassword"
}
```

**Response:**
```json
{
  "success": true
}
```

#### Login User

**Request:**
```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "mypassword"
}
```

**Response:**
```json
{
  "success": true
}
```

#### Register Device

**Request:**
```bash
POST /api/register
Content-Type: application/json

{
  "code": "123456",
  "game_system": "miyoo-flip"
}
```

**Response:**
```json
{
  "success": true,
  "code": "123456"
}
```

#### Claim Device (Link to User)

**Request:**
```bash
POST /api/claim
Content-Type: application/json

{
  "code": "123456",
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Device linked!"
}
```

#### Get Device Status

**Request:**
```bash
GET /api/status/123456
```

**Response:**
```json
{
  "status": "CONNECTED",
  "email": "user@example.com",
  "game_system": "miyoo-flip",
  "registered_at": "2026-01-30T06:00:00.000Z",
  "connected_at": "2026-01-30T06:05:00.000Z"
}
```

#### Upload Save

**Request:**
```bash
POST /api/saves/upload
Content-Type: application/json

{
  "code": "123456",
  "filename": "game.srm",
  "game_name": "game.srm",
  "checksum": "abc123...",
  "data": "base64_encoded_file_data"
}
```

**Response:**
```json
{
  "success": true,
  "save_id": "uuid-here"
}
```

---

## Data Storage

### User Model

```javascript
{
  email: String,          // Primary key
  password_hash: String,  // SHA256 hash
  created_at: Date        // ISO timestamp
}
```

### Device Model

```javascript
{
  code: String,           // Primary key (6 digits)
  status: String,         // "WAITING" | "CONNECTED"
  email: String,          // Owner's email (when connected)
  game_system: String,    // e.g., "miyoo-flip", "rg35xx"
  registered_at: Date,
  connected_at: Date      // When claimed by user
}
```

### Save Model

```javascript
{
  id: String,             // UUID
  code: String,           // Device code
  email: String,          // Owner's email
  filename: String,       // Original filename
  game_name: String,      // Display name
  uploaded_at: Date,
  checksum: String        // MD5 hash
}
```

---

## Security

### Current Implementation

| Aspect | Implementation | Notes |
|--------|---------------|-------|
| Password Hashing | SHA256 | ⚠️ Should use bcrypt |
| Device Codes | 6-digit random | 1M combinations |
| API Auth | Device code + email | Simple pairing |
| CORS | Open (*) | Too permissive |
| HTTPS | None | HTTP only |

### Security Concerns

1. **SHA256 for passwords** - Should use bcrypt
2. **Open CORS** - Should restrict origins
3. **No HTTPS** - Transmit in clear
4. **No rate limiting** - Vulnerable to abuse

### Recommendations for Production

1. **Use bcrypt** for password hashing
2. **Enable HTTPS** with TLS certificate
3. **Restrict CORS** to known origins
4. **Add rate limiting** on auth endpoints
5. **Use secure cookies** for web UI
6. **Add input validation** (currently minimal)

---

## Related Documentation

- [API.md](API.md) - Complete API reference
- [DEVELOPER.md](DEVELOPER.md) - Development guide
- [FEEDBACK.md](FEEDBACK.md) - Architecture review
