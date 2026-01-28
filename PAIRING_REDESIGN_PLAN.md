# RetroSync Pairing System Redesign Plan

## Goal
Netflix-style code pairing: Device shows code → User enters on dashboard → Device auto-connects

## Flow Overview

1. **Device Launch**
   - Device calls `/api/devices/code` → Gets unique code (e.g., "ABC123")
   - Device displays code on screen
   - Device stores code locally

2. **User Registration**
   - User goes to dashboard, logs in/registers (normal auth flow)
   - User navigates to "Add Device" page
   - User enters the code shown on device

3. **Pairing**
   - Dashboard calls `/api/devices/pair` with code → Links code to user account
   - Device polls `/api/devices/status` with code every 2 seconds
   - When code is linked, device automatically gets API key and connects

## Database Schema

### PairingCode (Simplified)
```prisma
model PairingCode {
  id          String    @id @default(uuid())
  code        String    @unique  // 6-character alphanumeric (e.g., "ABC123")
  userId      String?   // NULL until user pairs, then set to user.id
  deviceId    String?   // NULL until device is created, then set to device.id
  expiresAt   DateTime  // 15 minutes from creation
  used        Boolean   @default(false)
  usedAt      DateTime?
  createdAt   DateTime  @default(now())

  user        User?     @relation(fields: [userId], references: [id], onDelete: Cascade)
  device      Device?   @relation(fields: [deviceId], references: [id], onDelete: SetNull)

  @@index([code])
  @@index([userId])
}
```

### Device (Unchanged)
```prisma
model Device {
  id           String    @id @default(uuid())
  userId       String
  name         String
  deviceType   String
  apiKey       String    @unique
  lastSyncAt   DateTime?
  isActive     Boolean   @default(true)
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt

  user         User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  syncLogs     SyncLog[]
  pairingCode  PairingCode? @relation(fields: [id], references: [deviceId])

  @@index([userId])
  @@index([apiKey])
}
```

### User (Unchanged)
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

## API Endpoints

### 1. POST /api/devices/code
**Purpose:** Device gets a unique code on launch
**Auth:** None required
**Request:**
```json
{
  "deviceType": "miyoo_flip" // optional
}
```
**Response:**
```json
{
  "success": true,
  "data": {
    "code": "ABC123",
    "expiresAt": "2026-01-29T05:30:00Z"
  }
}
```
**Logic:**
- Generate unique 6-character alphanumeric code
- Create PairingCode with userId=null, deviceId=null
- Expires in 15 minutes
- Return code to device

### 2. POST /api/devices/pair
**Purpose:** User links code to their account
**Auth:** Required (JWT token)
**Request:**
```json
{
  "code": "ABC123"
}
```
**Response:**
```json
{
  "success": true,
  "data": {
    "code": "ABC123",
    "linked": true
  }
}
```
**Logic:**
- Find PairingCode by code
- Check if expired or already used
- Check if already linked to different user
- Update userId to current user's id
- Return success

### 3. POST /api/devices/status
**Purpose:** Device polls to check if code is linked and get API key
**Auth:** None required
**Request:**
```json
{
  "code": "ABC123"
}
```
**Response (waiting):**
```json
{
  "success": true,
  "data": {
    "status": "waiting",
    "message": "Waiting for user to enter code on dashboard"
  }
}
```
**Response (linked - auto-create device):**
```json
{
  "success": true,
  "data": {
    "status": "paired",
    "apiKey": "sk_abc123...",
    "userId": "user-uuid",
    "device": {
      "id": "device-uuid",
      "name": "Miyoo Flip 05:30",
      "deviceType": "miyoo_flip"
    }
  }
}
```
**Logic:**
- Find PairingCode by code
- If userId is null → return "waiting"
- If userId exists but deviceId is null → create Device, update PairingCode.deviceId, return API key
- If deviceId exists → return existing device info

## Client Flow

### Miyoo Device (Lua)
1. **On Launch:**
   - Check if API key exists locally
   - If yes → Go to CONNECTED state
   - If no → Call `/api/devices/code`, store code, show code on screen

2. **Polling (every 2 seconds):**
   - Call `/api/devices/status` with stored code
   - If status="waiting" → Keep showing code
   - If status="paired" → Save API key, switch to CONNECTED state

3. **Connected State:**
   - Show "UPLOAD SAVES" button
   - Can upload saves using API key

## Dashboard Flow

1. **User logs in/registers** (existing auth)
2. **User goes to "Add Device" page**
3. **User enters code from device**
4. **Dashboard calls `/api/devices/pair`**
5. **Device automatically detects link and pairs**

## Key Improvements

1. **Simpler Schema:** PairingCode has direct relation to Device (via deviceId)
2. **No System User:** Codes exist independently until linked
3. **Auto-Device Creation:** Device is created automatically when code is linked
4. **Clear States:** waiting → paired (no intermediate states)
5. **Single Poll Endpoint:** Device only needs to poll one endpoint

## Migration Strategy

1. Drop existing PairingCode table
2. Create new schema with proper relations
3. Update all API endpoints
4. Update client code
5. Test end-to-end flow
