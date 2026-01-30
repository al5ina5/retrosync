# RetroSync User Guide

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Creating an Account](#creating-an-account)
3. [Pairing Devices](#pairing-devices)
4. [How Sync Works](#how-sync-works)
5. [Managing Devices](#managing-devices)
6. [Configuring Save Locations](#configuring-save-locations)
7. [Viewing Saves](#viewing-saves)
8. [Sync Conflicts](#sync-conflicts)
9. [Account Settings](#account-settings)

---

## Overview

RetroSync keeps your retro game saves safe by automatically backing them up to the cloud and syncing them across all your devices.

### Key Concepts

| Term | Definition |
|------|------------|
| **Device** | Any handheld or PC running RetroSync |
| **Pairing Code** | 6-digit code that links a device to your account |
| **Save File** | Game save data (battery saves or save states) |
| **Sync** | The process of uploading/downloading saves |
| **Cloud** | Remote storage where saves are kept |

---

## Creating an Account

### Step 1: Access the Dashboard

Open your web browser and navigate to your RetroSync server URL:

```
http://YOUR-SERVER-IP:3000
```

Or for hosted instances:
```
https://retrosync.your-domain.com
```

### Step 2: Click "Get Started"

On the home page, click the "Get Started" button to begin.

### Step 3: Create Account

1. **Click "Create an account"** below the login form
2. **Enter your email** (will be your username)
3. **Create a password** (minimum 6 characters)
4. **Click "Create Account"**

### Step 4: Verify Email (Future)

⚠️ **Note:** Email verification is not yet implemented. Use a valid email address as it will be used for account recovery in the future.

### Step 5: You're In!

After creating an account, you'll be redirected to your dashboard where you can:
- View paired devices
- See cloud saves
- Generate pairing codes
- Manage settings

---

## Pairing Devices

Pairing connects a device to your RetroSync account using a 6-digit code.

### Method 1: Generate Code from Dashboard (Recommended)

#### Step 1: Generate Pairing Code

1. **Login** to your RetroSync dashboard
2. **Click "Add Device"** button
3. **A 6-digit code** will be displayed
4. **Note:** Code expires in 15 minutes!

#### Step 2: Enter Code on Device

**Python Client:**
```bash
retrosync setup
# Choose option 2: Enter pairing code
# Enter: YOUR-6-DIGIT-CODE
```

**LÖVE Client (Miyoo Flip):**
1. Launch RetroSync app
2. Code is displayed on screen
3. Enter code in dashboard first, then device connects automatically

**Shell Client:**
```bash
./setup.sh
# Choose option 2
# Enter: YOUR-6-DIGIT-CODE
```

#### Step 3: Confirm Pairing

Once you enter the code:
1. Device will show "Connected" status
2. Dashboard will show the new device
3. Automatic sync begins

### Method 2: Generate Code on Device

#### Step 1: Start Setup on Device

```bash
retrosync setup
# Choose option 1: Generate pairing code
```

#### Step 2: Note the Code

A 6-digit code will be displayed (e.g., `123456`)

#### Step 3: Complete Pairing in Dashboard

1. **Go to** Dashboard → Add Device
2. **Select** "I have a code from my device"
3. **Enter** the 6-digit code
4. **Click** "Pair Device"

#### Step 4: Device Auto-Connects

Device will automatically detect pairing and connect.

---

## How Sync Works

### Automatic Sync Process

```
┌──────────┐          ┌──────────┐          ┌──────────┐
│  Device  │   ──►    │  Cloud   │   ──►    │  Other   │
│  Saves   │  Upload  │  Storage │  Sync    │ Devices  │
└──────────┘          └──────────┘          └──────────┘
```

### Step 1: Save File Detected

When you save a game:
1. RetroSync detects the file change (within 2 seconds)
2. File is hashed to check if changed
3. If changed, upload begins

### Step 2: Upload to Cloud

1. File is uploaded to MinIO (S3-compatible storage)
2. Sync event is logged in database
3. Other devices are notified on next heartbeat

### Step 3: Other Devices Sync

1. Other devices poll for updates (every 30-60 seconds)
2. New files are downloaded automatically
3. Saves are placed in correct locations

### Sync Frequency

| Event | Sync Timing |
|-------|-------------|
| File change detected | ~2 seconds |
| Heartbeat to server | Every 30 seconds |
| Check for downloads | Every 60 seconds |
| Full sync check | On daemon start |

### What's Synced

✅ **Always Synced:**
- `.srm` files (battery saves)
- `.sav` files (generic saves)
- `.state` files (save states)
- `.mpk` files (controller paks)

❌ **Not Synced:**
- Save states during active play (configurable)
- System configuration files
- Screenshots or videos
- ROM files

---

## Managing Devices

### View All Devices

1. **Login** to dashboard
2. **Navigate** to "Devices" section
3. **View** all paired devices with status

### Device Status Indicators

| Icon | Status | Meaning |
|------|--------|---------|
| 🟢 | Online | Daemon running, connected |
| 🔴 | Offline | Daemon not running |
| ⚠️ | Error | Sync error occurred |
| ⏳ | Pairing | Waiting for code entry |

### Rename Device

1. **Click** device card
2. **Click** edit icon (pencil)
3. **Enter** new name
4. **Save** changes

### Remove Device

⚠️ **Warning:** Removing a device deletes all associated saves from the cloud!

1. **Click** device card
2. **Click** "Remove Device" button
3. **Confirm** removal

### Device Types

| Type | Description |
|------|-------------|
| `rg35xx` | Anbernic RG35XX+ (muOS) |
| `miyoo_flip` | Miyoo Flip (Spruce OS) |
| `windows` | Windows PC |
| `mac` | macOS |
| `linux` | Linux PC |

---

## Configuring Save Locations

### Default Save Locations

#### muOS (Anbernic RG35XX+)

| Emulator | Save Path |
|----------|-----------|
| RetroArch | `/mnt/SDCARD/RetroArch/saves/` |
| Genesis Plus | `/mnt/SDCARD/Saves/genesis/` |
| PPSSPP | `/mnt/SDCARD/PPSP/savedata/` |

#### Spruce OS (Miyoo Flip)

| Emulator | Save Path |
|----------|-----------|
| RetroArch | `/mnt/SDCARD/RetroArch/saves/` |
| Miyoo Cores | `/mnt/SDCARD/Saves/` |
| PocketStation | `/mnt/SDCARD/Saves/pocketsta/` |

#### PC (All Platforms)

| OS | Save Path |
|----|-----------|
| Windows | `%APPDATA%\RetroArch\saves\` |
| macOS | `~/Library/Application Support/RetroArch/saves/` |
| Linux | `~/.config/retroarch/saves/` |

### Custom Save Locations

#### Python Client

```bash
# Set custom save directory
retrosync config set save_directory /path/to/saves

# Add additional watch path
retrosync config add_watch_path /path/to/extra/saves
```

#### View Current Configuration

```bash
retrosync config show
```

### Auto-Detection

RetroSync automatically detects common save locations for:
- RetroArch
- Standalone emulators
- Custom configurations

---

## Viewing Saves

### Dashboard View

1. **Login** to dashboard
2. **Navigate** to "Saves" section
3. **Browse** all cloud saves
4. **Filter** by device, game, or date

### Save Information

Each save shows:
- **Game Name** (detected from filename)
- **Device** (which device uploaded)
- **Date** (last modified/uploaded)
- **Size** (file size)
- **Type** (battery save or save state)

### Download Individual Save

1. **Find** save in list
2. **Click** download icon
3. **File** downloads to your computer

### Delete Save

⚠️ **Warning:** Deleting from cloud is permanent!

1. **Find** save in list
2. **Click** trash icon
3. **Confirm** deletion

---

## Sync Conflicts

### What Causes Conflicts

A conflict occurs when:
1. You save on Device A
2. You save on Device B (same game, before syncing)
3. Both versions exist in cloud

### Conflict Resolution

RetroSync uses **Last-Write-Wins** strategy:

```
Timestamp: Device A  ────────────►  (wins)
Timestamp: Device B  ───────►
```

The file with the most recent modification time wins.

### Manual Conflict Resolution

To keep both versions:

1. **Download** the winning file
2. **Rename** to include device name:
   ```
   Super Mario 64.srm        # original (Device A)
   Super Mario 64-DeviceB.srm  # copy from Device B
   ```
3. **Upload** the renamed file
4. **Load** the appropriate file when needed on each device

### Conflict Prevention Tips

1. **Sync before switching devices** - Always run daemon on Device A before playing on Device B
2. **Close emulators properly** - Ensures saves are written to disk
3. **Wait for sync confirmation** - Check logs before powering off

---

## Account Settings

### Profile Settings

**Change Email:**
1. Settings → Profile
2. Enter new email
3. Save changes

**Change Password:**
1. Settings → Security
2. Enter current password
3. Enter new password
4. Save changes

### Notification Settings

⚠️ **Not yet implemented** - Future feature

Enable notifications for:
- Device online/offline
- Sync errors
- New device pairing
- Weekly backup summary

### Subscription

**Current Tiers:**

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Unlimited devices, 1GB storage |
| Pro | $5/mo | Unlimited storage, priority sync |
| Enterprise | Custom | Self-hosted support |

### Danger Zone

⚠️ **These actions are irreversible:**

- **Delete Account** - Removes all data, devices, and saves
- **Reset Sync** - Clears all cloud saves (devices keep local copies)

---

## Tips & Tricks

### Speed Up Sync

1. **Use wired internet** when possible
2. **Don't sync during gaming** - pause daemon
3. **Limit file types** - sync only saves, not states

### Save Space

1. **Configure exclusions** - Don't sync large state files
2. **Delete old saves** - Remove saves for games you've finished
3. **Compress states** - Some emulators support compressed states

### Battery Life (Handhelds)

1. **Run daemon only when needed** - Stop when not playing
2. **Sync before sleep** - Ensures saves are backed up
3. **Use shell client** - Uses less power than Python client

---

## Related Documentation

- [Installation Guide](INSTALLATION.md)
- [Compatibility List](COMPATIBILITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Developer Guide](DEVELOPER.md)
