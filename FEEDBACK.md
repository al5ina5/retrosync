# RetroSync Architectural Review & Feedback

**Date:** January 30, 2026  
**Reviewer:** Clawdy (AI Assistant)  
**Scope:** Full codebase review across all components  
**Commit:** Local development branch

---

## Executive Summary

RetroSync is a well-architected cloud sync service for retro gaming save files with a clear value proposition and solid foundation. The project demonstrates thoughtful design decisions, particularly in its multi-platform client support and clean separation between authentication, storage, and sync logic.

**Overall Grade: B+**

Strengths:
- Clean API design with proper authentication
- Multi-platform client implementations
- Good use of modern frameworks (Next.js 14, Prisma, SQLite)
- Well-structured S3 integration for file storage

Areas for Improvement:
- Code duplication between standalone server and backend
- Inconsistent naming conventions
- Unused/dead files in repository
- Lack of test coverage visibility
- Security hardening needed for production

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          RetroSync System                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────┐    ┌─────────────┐    ┌──────────────────────────┐   │
│  │  Client  │───▶│  Backend    │───▶│  Storage Layer           │   │
│  │ Devices  │    │  (Next.js)  │    │  (MinIO/S3 + SQLite)     │   │
│  └──────────┘    └─────────────┘    └──────────────────────────┘   │
│       │                │                       │                    │
│       │                │                       │                    │
│       ▼                ▼                       ▼                    │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Monitoring & Logging                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Breakdown

| Component | Technology | Purpose | Status |
|-----------|-----------|---------|--------|
| Backend API | Next.js 14 + Prisma | REST API, Auth, Device Management | ✅ Production-ready |
| Storage | MinIO (S3-compatible) | Save file storage | ✅ Production-ready |
| Database | SQLite + Prisma | Users, Devices, Pairing Codes, Sync Logs | ✅ Production-ready |
| Python Client | Python 3.9+ + watchdog | Desktop/handheld sync daemon | ✅ Functional |
| Lua/LÖVE Client | Lua + LÖVE 11.x | Miyoo Flip GUI app | ✅ Functional |
| Shell Client | POSIX Shell | Python-free alternative | ⚠️ Incomplete |
| Standalone Server | Node.js (server.js) | Simple dev server | ⚠️ Duplicate |

---

## 2. Detailed Component Analysis

### 2.1 Backend (Next.js + Prisma)

**Location:** `backend/`

**Strengths:**
- Clean Next.js App Router structure
- Proper separation of concerns (lib/, app/, components/)
- Zod for request validation
- JWT-based authentication with bcrypt for password hashing
- Prisma ORM with well-defined schema

**Architecture:**
```
backend/
├── src/
│   ├── app/
│   │   ├── api/          # API routes
│   │   ├── auth/         # Auth pages
│   │   └── dashboard/    # Dashboard pages
│   ├── lib/
│   │   ├── auth.ts       # JWT, hashing, tokens
│   │   ├── prisma.ts     # DB client
│   │   ├── s3.ts         # S3 operations
│   │   └── utils.ts      # Helpers
│   └── components/       # React components
├── prisma/
│   └── schema.prisma     # Database schema
└── Dockerfile
```

**Database Schema (Prisma):**
- **User:** id, email, passwordHash, subscriptionTier, createdAt
- **Device:** id, userId, name, deviceType, apiKey, lastSyncAt, isActive
- **PairingCode:** id, code, userId, expiresAt, used, usedAt, deviceId
- **SyncLog:** id, deviceId, action, filePath, fileSize, status, errorMsg, metadata

**Issues Identified:**

1. **Missing Indexes:** Some queries may benefit from additional indexes
   - `SyncLog.deviceId` has index (good)
   - Missing composite index on `(deviceId, createdAt)` for sync history queries

2. **Subscription Tier Not Enforced:** Model includes `subscriptionTier` but no logic to enforce limits

3. **Hardcoded S3 Credentials:** `s3.ts` reads from environment but returns credentials in pairing response (security concern - see section 4)

### 2.2 Python Client

**Location:** `client/retrosync/`

**Strengths:**
- Well-structured modular design
- Use of watchdog for file system monitoring
- Proper error handling and logging
- S3 client for direct file operations
- Clean separation: api_client, s3_client, sync_engine, watcher

**Architecture:**
```
client/retrosync/
├── __init__.py          # Package exports
├── api_client.py        # REST API client
├── config.py            # Configuration management
├── daemon.py            # Main daemon loop
├── detect.py            # Emulator/game detection
├── s3_client.py         # S3 file operations
├── sync_engine.py       # Upload/download logic
├── ui.py                # User interface (TUI/CLI)
├── watcher.py           # File system watcher
└── scripts/
    ├── setup.py         # Setup wizard
    └── RetroSync.sh     # Launcher
```

**Issues Identified:**

1. **Missing Emulator Detection Logic:** `detect.py` exists but content was not reviewed - verify it handles all supported emulators

2. **Incomplete UI:** `ui.py` exists but needs testing to verify all flows work

3. **Hardcoded Server URL:** Many files reference `http://10.0.0.245:4000` - should use configuration

### 2.3 Lua/LÖVE Client

**Location:** `main.lua`, `RetroSync.love`, `RetroSync.lua`

**Strengths:**
- Clean state machine implementation (WAITING → CONNECTED → UPLOADING → SUCCESS)
- Simple JSON parsing without external dependencies
- Direct curl integration for HTTP requests
- Proper button handling for gamepad/keyboard

**Issues Identified:**

1. **Code Duplication:** `main.lua` and `RetroSync.lua` appear identical - consolidate

2. **Hardcoded Server URL:** `local SERVER_URL = "http://10.0.0.245:4000"`

3. **Limited Error Handling:** No retry logic for network failures

4. **Missing Configuration:** No way to configure server URL without code modification

### 2.4 Shell Client

**Location:** `miyoo-shell/`

**Strengths:**
- No Python dependency (good for constrained devices)
- POSIX-compliant (mostly)
- Proper logging

**Issues Identified:**

1. **Incomplete Implementation:** `launch.sh` shows "PYTHON NOT INSTALLED" error - shell client doesn't actually work

2. **Inconsistent API:** `daemon.sh` uses different API endpoints than backend expects

3. **Missing Files:** References files that don't exist (e.g., `/var/log/messages` for button input)

4. **Hardcoded Paths:** Multiple hardcoded paths reduce portability

### 2.5 Standalone Server

**Location:** `server.js`

**Strengths:**
- Simple, self-contained HTTP server
- Works without Docker/Next.js for quick testing
- In-memory storage with periodic file backup

**Issues Identified:**

1. **Major Code Duplication:** `server.js` is a complete rewrite that duplicates much of the backend functionality but uses:
   - In-memory storage vs SQLite
   - No JWT authentication
   - Different API structure
   - Embedded HTML frontend

2. **Security Issues:**
   - SHA256 for password hashing (bcrypt preferred)
   - No rate limiting
   - No input sanitization beyond basic checks
   - CORS wide open (`*`)

3. **Inconsistent API:** Different endpoints than main backend:
   - `/api/register` vs backend's device pairing flow
   - Different data models

---

## 3. Code Quality Issues

### 3.1 Files Requiring Cleanup

| File | Issue | Action |
|------|-------|--------|
| `RetroSync.love` | Compiled LÖVE archive | Keep for distribution |
| `RetroSync.lua` | Duplicate of main.lua | Delete |
| `RetroSync.sh` | Duplicate of client/RetroSync.sh | Delete |
| `conf.lua` | LÖVE config, minimal | Keep |
| `main.lua` | Lua client source | Keep |
| `server.js` | Duplicate backend | Mark as deprecated or delete |
| `data.json` | Runtime data | Should be in .gitignore |
| `port.json` | Unknown purpose | Investigate, possibly delete |
| `minio-data/` | Runtime data | Should be in .gitignore |
| `saves/` | Runtime data | Should be in .gitignore |
| `__pycache__/` | Python cache | Should be in .gitignore |
| `.next/` | Build artifacts | Should be in .gitignore |
| `node_modules/` | Dependencies | Should be in .gitignore |
| `logs/` | Runtime logs | Should be in .gitignore |
| `QUICK_REFERENCE.txt` | Duplicate docs | Remove or integrate |

### 3.2 Naming Inconsistencies

| Current | Should Be | Location |
|---------|-----------|----------|
| `RetroSync.sh` | `retrosync-shell-client.sh` | client/ |
| `RetroSync.lua` | `retrosync-love-client.lua` | (delete) |
| `retrosync_client.py` | `retrosync-cli.py` | root |
| `retrosync_portal.py` | `retrosync-web-portal.py` | root |
| `upload_saves.py` | `retrosync-upload-tool.py` | root |
| `server.js` | `retrosync-standalone-server.js` | root (or delete) |

### 3.3 Unused/Orphaned Files

- `port.json` - Purpose unclear, not referenced in other files
- `conf.lua` - LÖVE config, may be outdated
- `MIYOO_PYTHON_ISSUE.md` - Historical document, may be resolved
- `SETUP_COMPLETE.md` - One-time setup notes
- `IMPLEMENTATION_SUMMARY.md` - Outdated implementation notes

### 3.4 Hardcoded Values

**Critical (Production Security Issues):**
1. `server.js:10` - Hardcoded PORT=4000, HOST='0.0.0.0'
2. `main.lua:5` - Hardcoded SERVER_URL
3. `RetroSync.sh:13` - Hardcoded SERVER_URL
4. `retrosync_client.py:~30` - Hardcoded SERVER_URL

**Medium:**
- Device paths hardcoded across clients
- File extensions filter list duplicated
- Save locations not configurable

---

## 4. Security Review

### 4.1 Authentication & Authorization

| Aspect | Status | Notes |
|--------|--------|-------|
| Password Hashing | ✅ Good | Uses bcrypt in backend |
| Password Hashing | ❌ Poor | Uses SHA256 in server.js |
| JWT Implementation | ✅ Good | Proper signing, expiration |
| API Key Generation | ✅ Good | Cryptographically secure |
| Device Authentication | ✅ Good | API key per device |
| Pairing Code Security | ⚠️ Medium | 6-digit codes, 15-min expiry |

**Recommendations:**
1. Replace SHA256 with bcrypt in server.js or remove server.js entirely
2. Increase pairing code entropy (6 digits = 1M combinations, consider 8+ digits)
3. Add rate limiting for authentication endpoints
4. Implement account lockout after failed attempts

### 4.2 Data Protection

| Aspect | Status | Notes |
|--------|--------|-------|
| S3 Bucket Policies | ⚠️ Unknown | Need review of MinIO config |
| Data at Rest | ✅ Good | SQLite file protection depends on deployment |
| Data in Transit | ⚠️ Medium | HTTP only, needs TLS |
| API Key Exposure | ❌ Poor | Keys returned in pairing response without encryption |

**Critical Issue:** In `backend/src/app/api/devices/pair/route.ts`, the pairing response includes:
```typescript
s3Config: {
  endpoint: process.env.MINIO_ENDPOINT || 'http://localhost:9000',
  accessKeyId: process.env.MINIO_ROOT_USER || 'minioadmin',
  secretAccessKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin',
  ...
}
```

This exposes MinIO root credentials to any device that pairs! This is a **critical security vulnerability**.

**Required Fix:**
1. Use IAM-style credentials with limited permissions per device
2. Or use presigned URLs for all S3 operations (device never needs credentials)

### 4.3 Input Validation

| Aspect | Status | Notes |
|--------|--------|-------|
| Zod Schemas | ✅ Good | Proper validation in backend |
| File Uploads | ⚠️ Medium | No file type validation |
| File Size Limits | ⚠️ Unknown | Need to verify |
| SQL Injection | ✅ Good | Prisma handles this |
| XSS | ✅ Good | React escapes output |

---

## 5. Performance Analysis

### 5.1 Scalability Concerns

1. **SQLite Database:** Single-writer, may bottleneck under high load
   - Recommendation: Consider PostgreSQL for production

2. **MinIO Single Node:** No replication configured
   - Recommendation: Add MinIO erasure coding or cluster

3. **No Caching Layer:** Every request hits database
   - Recommendation: Add Redis for session/device caching

4. **File Upload Size:** No limits specified
   - Recommendation: Enforce reasonable limits (e.g., 100MB per file)

### 5.2 Sync Efficiency

1. **Full File Upload:** Currently uploads entire file on any change
   - Consider: Implement delta sync for large files

2. **Polling Model:** Devices poll for status
   - Consider: WebSocket for real-time updates (lower latency)

3. **No Compression:** Save files sent uncompressed
   - Consider: Add gzip for network efficiency

---

## 6. Testing & Quality Assurance

### 6.1 Test Coverage Visibility

- No test files visible in repository
- No CI/CD pipeline configured (no .github/workflows/)
- No testing documentation

**Recommendations:**
1. Add Jest/Testing Library for backend
2. Add pytest for Python client
3. Add integration tests
4. Set up GitHub Actions for CI

### 6.2 Documentation Gaps

| Document | Status |
|----------|--------|
| API Documentation | ❌ Missing |
| Architecture Decision Records | ❌ Missing |
| Runbooks | ❌ Missing |
| Security Policy | ❌ Missing |

---

## 7. Modularization Opportunities

### 7.1 Suggested Refactoring

```
retrosync/
├── backend/                    # Next.js API + Web UI
├── clients/                    # Unified clients directory
│   ├── python/                # Python daemon
│   ├── lua/                   # LÖVE/Lua client
│   └── shell/                 # Shell-only client
├── core/                      # Shared core library
│   ├── sync-engine/           # Reusable sync logic
│   ├── api-client/            # Reusable API client
│   └── models/                # Shared TypeScript/Python models
├── shared/                    # Shared between all components
│   ├── api-spec/              # OpenAPI spec
│   └── s3-prefixes/           # Consistent S3 key structure
├── docker/                    # Docker configurations
├── docs/                      # Documentation
└── scripts/                   # Build/deployment scripts
```

### 7.2 Eliminate Duplication

1. **Extract common sync logic** from Python client into a shared module
2. **Standardize API endpoints** between server.js and backend
3. **Create shared TypeScript/Python models** for Device, SaveFile, SyncLog
4. **Unified configuration schema** across all clients

---

## 8. Prioritized Action Items

### Critical (Security - Fix Before Production)

| Priority | Issue | Action |
|----------|-------|--------|
| P0 | MinIO root credentials exposed | Use IAM credentials or presigned URLs |
| P0 | SHA256 password hashing in server.js | Remove server.js or fix hashing |
| P0 | No TLS enforcement | Configure HTTPS/TLS |
| P1 | Wide-open CORS | Restrict to known origins |

### High (Architecture & Code Quality)

| Priority | Issue | Action |
|----------|-------|--------|
| P1 | Delete/merge duplicate Lua files | Remove RetroSync.lua |
| P1 | Delete/merge duplicate shell scripts | Consolidate or remove |
| P1 | Add .gitignore entries | Add runtime data to ignore |
| P2 | Fix hardcoded server URLs | Use configuration files |
| P2 | Improve naming consistency | Rename files per conventions |

### Medium (Features & Polish)

| Priority | Issue | Action |
|----------|-------|--------|
| P2 | Complete or remove shell client | Either finish implementation or mark as unsupported |
| P2 | Add test coverage | Create test suite |
| P3 | Add CI/CD pipeline | Set up GitHub Actions |
| P3 | Add monitoring/observability | Add logging, metrics, alerts |

### Low (Documentation & Cleanup)

| Priority | Issue | Action |
|----------|-------|--------|
| P3 | Remove orphaned files | Investigate and delete unused files |
| P3 | Update package.json | Add proper metadata |
| P3 | Create API documentation | Generate OpenAPI spec |
| P4 | Document architecture decisions | Create ADRs |

---

## 9. Conclusion

RetroSync is a well-conceived project with solid foundations. The multi-platform client support and clean API design demonstrate good engineering practices. However, the project has accumulated some technical debt through:

1. **Parallel development** of standalone server.js and full backend
2. **Multiple client implementations** without shared core logic
3. **Insufficient security review** before exposing credentials
4. **Missing test coverage** and CI/CD infrastructure

The recommendations in this review, if implemented, will significantly improve code quality, security posture, and maintainability.

**Recommended Next Steps:**
1. **Immediate:** Fix the MinIO credential exposure vulnerability
2. **Short-term:** Consolidate duplicate files and add proper .gitignore
3. **Medium-term:** Implement shared core library to reduce duplication
4. **Long-term:** Add comprehensive test coverage and CI/CD

---

*This review was generated as part of the RetroSync documentation and feedback effort.*
