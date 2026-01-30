# RetroSync API Documentation

## Table of Contents
- [Overview](#overview)
- [Base URL](#base-url)
- [Authentication](#authentication)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [API Endpoints](#api-endpoints)
  - [Authentication](#authentication-endpoints)
  - [Device Management](#device-management-endpoints)
  - [Synchronization](#synchronization-endpoints)
- [WebSocket Events](#websocket-events-future)
- [Examples](#examples)

---

## Overview

RetroSync provides a **RESTful API** for managing user accounts, device pairing, and save file synchronization. The API uses JSON for request and response bodies and follows standard HTTP conventions.

### API Characteristics

- **Protocol**: HTTP/HTTPS
- **Data Format**: JSON
- **Authentication**: JWT (users), API Key (devices)
- **Versioning**: Not versioned (v1 implicit)
- **CORS**: Enabled for web dashboard

---

## Base URL

### Development
```
http://localhost:3000/api
```

### Production (Example)
```
https://retrosync.example.com/api
```

All endpoints documented below are relative to this base URL.

---

## Authentication

RetroSync uses two authentication methods:

### 1. JWT Tokens (Web Users)

Used by the web dashboard for user operations.

**Header Format**:
```http
Authorization: Bearer <jwt_token>
```

**Token Lifetime**: 30 days

**Example**:
```http
GET /api/devices
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 2. API Keys (Devices)

Used by client devices for sync operations.

**Header Format**:
```http
X-API-Key: <api_key>
```

**Key Format**: 64-character hexadecimal string

**Example**:
```http
POST /api/sync/heartbeat
X-API-Key: a1b2c3d4e5f6...
```

---

## Error Handling

### Error Response Format

All error responses follow this structure:

```json
{
  "success": false,
  "error": "Error message description"
}
```

### HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Authenticated but not authorized |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource conflict (e.g., email exists) |
| 422 | Unprocessable Entity | Validation error |
| 500 | Internal Server Error | Server error |
| 502 | Bad Gateway | Storage service error |

### Common Error Messages

```json
{
  "success": false,
  "error": "Invalid email address"
}
```

```json
{
  "success": false,
  "error": "API key is required"
}
```

```json
{
  "success": false,
  "error": "Pairing code has expired"
}
```

---

## Rate Limiting

**Current**: Not implemented

**Planned**:
- 100 requests/minute for authenticated users
- 10 requests/minute for unauthenticated endpoints
- 1000 requests/hour for device sync operations

Rate limit headers (future):
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

---

## API Endpoints

## Authentication Endpoints

### Register User

Create a new user account.

**Endpoint**: `POST /api/auth/register`

**Authentication**: None (public)

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe"  // optional
}
```

**Validation**:
- `email`: Valid email format, unique
- `password`: Minimum 8 characters
- `name`: Optional, any string

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "user@example.com",
      "name": "John Doe",
      "subscriptionTier": "free",
      "createdAt": "2024-01-27T10:30:00.000Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Responses**:

*400 Bad Request* - Invalid email:
```json
{
  "success": false,
  "error": "Invalid email address"
}
```

*400 Bad Request* - Password too short:
```json
{
  "success": false,
  "error": "Password must be at least 8 characters"
}
```

*409 Conflict* - Email exists:
```json
{
  "success": false,
  "error": "User with this email already exists"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123",
    "name": "John Doe"
  }'
```

---

### Login User

Authenticate an existing user.

**Endpoint**: `POST /api/auth/login`

**Authentication**: None (public)

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "user@example.com",
      "name": "John Doe",
      "subscriptionTier": "free"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error Responses**:

*401 Unauthorized* - Invalid credentials:
```json
{
  "success": false,
  "error": "Invalid email or password"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123"
  }'
```

---

## Device Management Endpoints

### Create Pairing Code

Generate a 6-digit pairing code for device setup.

**Endpoint**: `POST /api/devices/create-pairing-code`

**Authentication**: JWT token (required)

**Request Headers**:
```http
Authorization: Bearer <jwt_token>
```

**Request Body**: None (empty)

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Pairing code created successfully",
  "data": {
    "code": "123456",
    "expiresAt": "2024-01-27T10:45:00.000Z",
    "qrCode": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
  }
}
```

**Response Fields**:
- `code`: 6-digit pairing code (string)
- `expiresAt`: ISO 8601 timestamp (expires in 15 minutes)
- `qrCode`: Data URL containing QR code image (base64 PNG)

**Error Responses**:

*401 Unauthorized* - Missing token:
```json
{
  "success": false,
  "error": "Authorization token is required"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:3000/api/devices/create-pairing-code \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

### Pair Device

Exchange pairing code for device credentials.

**Endpoint**: `POST /api/devices/pair`

**Authentication**: None (uses pairing code)

**Request Body**:
```json
{
  "code": "123456",
  "deviceName": "My Anbernic RG35XX+",
  "deviceType": "rg35xx"
}
```

**Validation**:
- `code`: Exactly 6 digits
- `deviceName`: Non-empty string
- `deviceType`: One of: `rg35xx`, `miyoo_flip`, `windows`, `mac`, `linux`, `other`

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Device paired successfully",
  "data": {
    "device": {
      "id": "3e3944bc-3b0d-4f21-984d-1428522a1ada",
      "name": "My Anbernic RG35XX+",
      "deviceType": "rg35xx"
    },
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "apiKey": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
    "s3Config": {
      "endpoint": "http://localhost:9000",
      "accessKeyId": "minioadmin",
      "secretAccessKey": "minioadmin",
      "bucket": "retrosync-saves"
    }
  }
}
```

**Response Fields**:
- `device.id`: UUID of created device
- `userId`: UUID of owner user
- `apiKey`: 64-char hex API key for authentication
- `s3Config`: S3 credentials for direct storage access

**Error Responses**:

*400 Bad Request* - Invalid code format:
```json
{
  "success": false,
  "error": "Code must be 6 digits"
}
```

*404 Not Found* - Code doesn't exist:
```json
{
  "success": false,
  "error": "Invalid pairing code"
}
```

*400 Bad Request* - Code already used:
```json
{
  "success": false,
  "error": "Pairing code has already been used"
}
```

*400 Bad Request* - Code expired:
```json
{
  "success": false,
  "error": "Pairing code has expired"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:3000/api/devices/pair \
  -H "Content-Type: application/json" \
  -d '{
    "code": "123456",
    "deviceName": "My Anbernic RG35XX+",
    "deviceType": "rg35xx"
  }'
```

---

### List Devices

Get all devices for the authenticated user.

**Endpoint**: `GET /api/devices`

**Authentication**: JWT token (required)

**Request Headers**:
```http
Authorization: Bearer <jwt_token>
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "devices": [
      {
        "id": "3e3944bc-3b0d-4f21-984d-1428522a1ada",
        "name": "My Anbernic RG35XX+",
        "deviceType": "rg35xx",
        "lastSyncAt": "2024-01-27T10:30:00.000Z",
        "isActive": true,
        "createdAt": "2024-01-20T08:15:00.000Z"
      },
      {
        "id": "91f07ca4-6e9d-45d0-8792-de4ad6d15d4d",
        "name": "My Miyoo Flip",
        "deviceType": "miyoo_flip",
        "lastSyncAt": "2024-01-27T10:28:00.000Z",
        "isActive": true,
        "createdAt": "2024-01-22T14:30:00.000Z"
      }
    ],
    "count": 2
  }
}
```

**cURL Example**:
```bash
curl http://localhost:3000/api/devices \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

### Delete Device

Remove a device from the account.

**Endpoint**: `DELETE /api/devices`

**Authentication**: JWT token (required)

**Query Parameters**:
- `deviceId` (required): UUID of device to delete

**Request Example**:
```http
DELETE /api/devices?deviceId=3e3944bc-3b0d-4f21-984d-1428522a1ada
Authorization: Bearer <jwt_token>
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Device deleted successfully"
}
```

**Error Responses**:

*404 Not Found* - Device doesn't exist:
```json
{
  "success": false,
  "error": "Device not found"
}
```

*403 Forbidden* - Device belongs to another user:
```json
{
  "success": false,
  "error": "Not authorized to delete this device"
}
```

**cURL Example**:
```bash
curl -X DELETE "http://localhost:3000/api/devices?deviceId=3e3944bc-3b0d-4f21-984d-1428522a1ada" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## Synchronization Endpoints

### Send Heartbeat

Device check-in to update last sync time.

**Endpoint**: `POST /api/sync/heartbeat`

**Authentication**: API Key (required)

**Request Headers**:
```http
X-API-Key: <api_key>
```

**Request Body**: None (empty)

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Heartbeat received",
  "data": {
    "deviceId": "3e3944bc-3b0d-4f21-984d-1428522a1ada",
    "deviceName": "My Anbernic RG35XX+",
    "lastSyncAt": "2024-01-27T10:30:00.000Z"
  }
}
```

**Error Responses**:

*401 Unauthorized* - Missing API key:
```json
{
  "success": false,
  "error": "API key is required"
}
```

*401 Unauthorized* - Invalid API key:
```json
{
  "success": false,
  "error": "Invalid API key"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:3000/api/sync/heartbeat \
  -H "X-API-Key: a1b2c3d4e5f6..."
```

**Frequency**: Recommended every 60 seconds

---

### List Files

Get list of available save files in cloud storage.

**Endpoint**: `GET /api/sync/files`

**Authentication**: API Key (required)

**Request Headers**:
```http
X-API-Key: <api_key>
```

**Query Parameters** (all optional):
- `emulator`: Filter by emulator type (e.g., "gba", "nes")
- `game`: Filter by game identifier

**Request Examples**:
```http
GET /api/sync/files
GET /api/sync/files?emulator=gba
GET /api/sync/files?emulator=gba&game=pokemon_emerald
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "files": [
      {
        "key": "550e8400-e29b-41d4-a716-446655440000/3e3944bc-3b0d-4f21-984d-1428522a1ada/gba/pokemon_emerald/pokemon_emerald.sav",
        "size": 131072,
        "lastModified": "2024-01-27T10:25:00.000Z"
      },
      {
        "key": "550e8400-e29b-41d4-a716-446655440000/91f07ca4-6e9d-45d0-8792-de4ad6d15d4d/gba/pokemon_emerald/pokemon_emerald.sav",
        "size": 131072,
        "lastModified": "2024-01-27T10:28:00.000Z"
      }
    ],
    "count": 2
  }
}
```

**Response Fields**:
- `key`: Full S3 key path
- `size`: File size in bytes
- `lastModified`: ISO 8601 timestamp

**cURL Example**:
```bash
curl "http://localhost:3000/api/sync/files?emulator=gba" \
  -H "X-API-Key: a1b2c3d4e5f6..."
```

---

### Log Sync Event

Record a synchronization event (upload, download, conflict).

**Endpoint**: `POST /api/sync/log`

**Authentication**: API Key (required)

**Request Headers**:
```http
X-API-Key: <api_key>
Content-Type: application/json
```

**Request Body**:
```json
{
  "action": "upload",
  "filePath": "/mnt/SDCARD/Saves/GBA/pokemon_emerald.sav",
  "fileSize": 131072,
  "status": "success",
  "errorMsg": null,
  "metadata": null
}
```

**Field Validation**:
- `action` (required): One of `upload`, `download`, `delete`, `conflict`
- `filePath` (required): String, file path
- `fileSize` (optional): Integer, bytes
- `status` (optional): One of `success`, `failed`, `pending` (default: "success")
- `errorMsg` (optional): String, error description
- `metadata` (optional): String, JSON-encoded additional data

**Success Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "message": "File sync logged successfully"
  }
}
```

**Error Responses**:

*400 Bad Request* - Missing required field:
```json
{
  "success": false,
  "error": "filePath and action are required"
}
```

**cURL Example**:
```bash
curl -X POST http://localhost:3000/api/sync/log \
  -H "X-API-Key: a1b2c3d4e5f6..." \
  -H "Content-Type: application/json" \
  -d '{
    "action": "upload",
    "filePath": "/mnt/SDCARD/Saves/GBA/pokemon_emerald.sav",
    "fileSize": 131072,
    "status": "success"
  }'
```

---

### Get Sync Logs

Retrieve sync history for devices.

**Endpoint**: `GET /api/sync/log`

**Authentication**: API Key (required)

**Request Headers**:
```http
X-API-Key: <api_key>
```

**Query Parameters** (all optional):
- `deviceId`: Filter by device UUID
- `limit`: Maximum number of logs (default: 50, max: 100)
- `offset`: Pagination offset (default: 0)

**Request Examples**:
```http
GET /api/sync/log
GET /api/sync/log?limit=20&offset=0
GET /api/sync/log?deviceId=3e3944bc-3b0d-4f21-984d-1428522a1ada
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "log-uuid-1",
        "deviceId": "3e3944bc-3b0d-4f21-984d-1428522a1ada",
        "action": "upload",
        "filePath": "/mnt/SDCARD/Saves/GBA/pokemon_emerald.sav",
        "fileSize": 131072,
        "status": "success",
        "errorMsg": null,
        "metadata": null,
        "createdAt": "2024-01-27T10:25:00.000Z"
      },
      {
        "id": "log-uuid-2",
        "deviceId": "91f07ca4-6e9d-45d0-8792-de4ad6d15d4d",
        "action": "download",
        "filePath": "/mnt/SDCARD/Saves/GBA/pokemon_emerald.sav",
        "fileSize": 131072,
        "status": "success",
        "errorMsg": null,
        "metadata": null,
        "createdAt": "2024-01-27T10:28:00.000Z"
      }
    ],
    "total": 150,
    "limit": 50,
    "offset": 0
  }
}
```

**Response Fields**:
- `logs`: Array of sync log entries
- `total`: Total number of logs matching filter
- `limit`: Number of logs returned
- `offset`: Current pagination offset

**cURL Example**:
```bash
curl "http://localhost:3000/api/sync/log?limit=20" \
  -H "X-API-Key: a1b2c3d4e5f6..."
```

---

## WebSocket Events (Future)

**Status**: Planned, not yet implemented

### Connection

```javascript
const ws = new WebSocket('ws://localhost:3000/ws');
ws.send(JSON.stringify({
  type: 'auth',
  apiKey: 'a1b2c3d4e5f6...'
}));
```

### Events

**File Uploaded**:
```json
{
  "type": "file_uploaded",
  "deviceId": "3e3944bc-3b0d-4f21-984d-1428522a1ada",
  "filePath": "gba/pokemon_emerald/pokemon_emerald.sav",
  "timestamp": "2024-01-27T10:30:00.000Z"
}
```

**File Downloaded**:
```json
{
  "type": "file_downloaded",
  "deviceId": "91f07ca4-6e9d-45d0-8792-de4ad6d15d4d",
  "filePath": "gba/pokemon_emerald/pokemon_emerald.sav",
  "timestamp": "2024-01-27T10:30:30.000Z"
}
```

**Conflict Detected**:
```json
{
  "type": "conflict",
  "filePath": "gba/pokemon_emerald/pokemon_emerald.sav",
  "devices": ["device-id-1", "device-id-2"],
  "resolution": "last_write_wins",
  "timestamp": "2024-01-27T10:31:00.000Z"
}
```

---

## Examples

### Complete Device Pairing Flow

```bash
#!/bin/bash

# Step 1: User registers
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "name": "Test User"
  }')

TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.data.token')
echo "Token: $TOKEN"

# Step 2: Create pairing code
PAIRING_RESPONSE=$(curl -s -X POST http://localhost:3000/api/devices/create-pairing-code \
  -H "Authorization: Bearer $TOKEN")

CODE=$(echo $PAIRING_RESPONSE | jq -r '.data.code')
echo "Pairing Code: $CODE"

# Step 3: Pair device
DEVICE_RESPONSE=$(curl -s -X POST http://localhost:3000/api/devices/pair \
  -H "Content-Type: application/json" \
  -d "{
    \"code\": \"$CODE\",
    \"deviceName\": \"My Device\",
    \"deviceType\": \"linux\"
  }")

API_KEY=$(echo $DEVICE_RESPONSE | jq -r '.data.apiKey')
echo "API Key: $API_KEY"

# Step 4: Send heartbeat
curl -X POST http://localhost:3000/api/sync/heartbeat \
  -H "X-API-Key: $API_KEY"
```

### Python Client Example

```python
import requests
import time

class RetroSyncClient:
    def __init__(self, api_url, api_key):
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({'X-API-Key': api_key})
    
    def heartbeat(self):
        """Send heartbeat to server"""
        response = self.session.post(f'{self.api_url}/api/sync/heartbeat')
        response.raise_for_status()
        return response.json()
    
    def list_files(self, emulator=None, game=None):
        """List available files"""
        params = {}
        if emulator:
            params['emulator'] = emulator
        if game:
            params['game'] = game
        
        response = self.session.get(
            f'{self.api_url}/api/sync/files',
            params=params
        )
        response.raise_for_status()
        return response.json()
    
    def log_sync(self, action, file_path, file_size=None, status='success'):
        """Log a sync event"""
        response = self.session.post(
            f'{self.api_url}/api/sync/log',
            json={
                'action': action,
                'filePath': file_path,
                'fileSize': file_size,
                'status': status
            }
        )
        response.raise_for_status()
        return response.json()

# Usage
client = RetroSyncClient(
    api_url='http://localhost:3000',
    api_key='your-api-key-here'
)

# Send heartbeat every minute
while True:
    try:
        result = client.heartbeat()
        print(f"Heartbeat: {result}")
        time.sleep(60)
    except Exception as e:
        print(f"Error: {e}")
        time.sleep(5)
```

### JavaScript/TypeScript Example

```typescript
import axios, { AxiosInstance } from 'axios';

class RetroSyncAPI {
  private client: AxiosInstance;

  constructor(apiUrl: string, apiKey: string) {
    this.client = axios.create({
      baseURL: apiUrl,
      headers: {
        'X-API-Key': apiKey,
      },
    });
  }

  async heartbeat() {
    const response = await this.client.post('/api/sync/heartbeat');
    return response.data;
  }

  async listFiles(emulator?: string, game?: string) {
    const response = await this.client.get('/api/sync/files', {
      params: { emulator, game },
    });
    return response.data;
  }

  async logSync(
    action: 'upload' | 'download' | 'delete' | 'conflict',
    filePath: string,
    fileSize?: number,
    status: 'success' | 'failed' | 'pending' = 'success'
  ) {
    const response = await this.client.post('/api/sync/log', {
      action,
      filePath,
      fileSize,
      status,
    });
    return response.data;
  }
}

// Usage
const api = new RetroSyncAPI('http://localhost:3000', 'your-api-key');

// Send heartbeat
setInterval(async () => {
  try {
    const result = await api.heartbeat();
    console.log('Heartbeat:', result);
  } catch (error) {
    console.error('Heartbeat failed:', error);
  }
}, 60000);
```

---

## Best Practices

### Client Implementation

1. **Retry Logic**: Implement exponential backoff for failed requests
   ```
   Retry delays: 1s, 2s, 4s, 8s, 16s, max 60s
   ```

2. **Heartbeat Frequency**: Send every 60 seconds
   ```
   Too frequent: Wastes bandwidth
   Too infrequent: Device appears offline
   ```

3. **File Listing**: Poll every 5 minutes
   ```
   Balance between responsiveness and server load
   ```

4. **Error Handling**: Log errors locally and continue syncing
   ```
   Don't crash on single file failure
   ```

5. **Bandwidth**: Upload only changed files
   ```
   Use hash comparison before upload
   ```

### Security

1. **API Key Storage**: Store in secure location
   ```
   chmod 600 ~/.retrosync/config.json
   ```

2. **HTTPS**: Always use HTTPS in production
   ```
   http://localhost:3000  (dev only)
   https://api.example.com  (production)
   ```

3. **Token Refresh**: Re-login before JWT expires
   ```
   Check exp claim in JWT payload
   ```

### Performance

1. **Batch Logging**: Log multiple events in single request (future)
2. **Compression**: Compress large save files before upload (future)
3. **Delta Sync**: Only upload changed portions (future)

---

## Changelog

### Version 1.0 (Current)

**Released**: 2024-01-27

- Initial API release
- Authentication (register, login)
- Device pairing with 6-digit codes
- Sync endpoints (heartbeat, files, logs)
- JWT and API key authentication

### Future Versions

**v1.1** (Planned):
- WebSocket support for real-time updates
- Batch sync log endpoint
- File versioning API
- Presigned URL generation for direct S3 access

**v2.0** (Future):
- GraphQL API option
- Selective sync preferences
- Quota management endpoints
- Advanced conflict resolution options

---

## Support

- **Documentation**: https://github.com/yourusername/retrosync/docs
- **Issues**: https://github.com/yourusername/retrosync/issues
- **API Status**: https://status.retrosync.example.com (future)

---

**API Version**: 1.0  
**Last Updated**: 2024-01-30  
**Maintained By**: RetroSync Development Team
