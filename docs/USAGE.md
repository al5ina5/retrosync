# RetroSync User Guide

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [How RetroSync Works](#how-retrosync-works)
2. [Creating an Account](#creating-an-account)
3. [Pairing Devices](#pairing-devices)
4. [Syncing Saves](#syncing-saves)
5. [Managing Devices](#managing-devices)
6. [Viewing Saves](#viewing-saves)
7. [Common Tasks](#common-tasks)

---

## How RetroSync Works

### The Core Concept

RetroSync keeps your game saves synchronized across all your devices by:

1. **Device generates a pairing code** when RetroSync starts
2. **You enter that code** in the web dashboard to link the device
3. **Device checks in** periodically to see if it's linked
4. **Once linked**, saves upload automatically when games are saved
5. **Other devices** can download the latest saves

### Data Flow

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Game    │───▶│  Retro   │───▶│  Server  │───▶│  Cloud   │
│  Save    │    │  Sync    │    │ (port4000)│   │  Storage │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                                             │
                                             ▼
                                      ┌──────────┐
                                      │  Other   │
                                      │  Devices │
                                      └──────────┘
```

### What Gets Synced

✅ **These files sync automatically:**
- `.srm` - Battery saves (SRAM)
- `.sav` - Generic saves
- `.state` - Save states
- `.mpk` - N64 controller pak

❌ **These don't sync:**
- ROM files
- BIOS files
- Screenshots
- Cheat files

---

## Creating an Account

### Step 1: Open Dashboard

Navigate to your RetroSync server in a browser:

```
http://YOUR_SERVER_IP:4000
```

You'll see the RetroSync home page with a **"Get Started →"** button.

### Step 2: Create Account

1. Click **"Get Started →"**
2. Click **"Create an account"**
3. Enter your **email** (this is your username)
4. Create a **password** (minimum 6 characters)
5. Click **"Create Account"**

### Step 3: You're In!

After creating an account, you'll see your dashboard with:
- **Devices** section - shows linked devices
- **Saves** section - shows cloud saves

---

## Pairing Devices

Pairing links a device to your RetroSync account using a 6-digit code.

### The Correct Flow

#### On the Device:

1. **Launch RetroSync** on your handheld/PC
2. **A 6-digit code** appears on screen (e.g., "123456")
3. **Code stays** until successfully paired

#### On the Web Dashboard:

1. **Login** to `http://YOUR_SERVER_IP:4000`
2. Look for **"Add Device"** section
3. Enter the **6-digit code** from your device
4. Click **"Link Device"**

#### On the Device:

- Status changes from **"PAIRING CODE"** → **"CONNECTED!"**
- Your email is shown on screen

### Troubleshooting Pairing

| Problem | Solution |
|---------|----------|
| "Device not found" | Make sure device app is running |
| "Invalid code" | Re-enter code exactly as shown |
| Code expired | Restart app to get new code |
| "Account not found" | Create account first, then pair |

---

## Syncing Saves

### Automatic Sync

Once paired, RetroSync works automatically:

1. **You save a game** in your emulator
2. **RetroSync detects** the file change (within ~2 seconds)
3. **File uploads** to the server
4. **Other devices** get the save on next check

### Manual Upload (Miyoo/Handhelds)

On handheld devices with display:

1. Status shows **"CONNECTED!"**
2. Press **A** button
3. Saves upload immediately
4. Shows confirmation when done

### Checking Sync Status

**On Device:**
- Status indicator shows connection state
- Upload progress on screen

**On Dashboard:**
- Visit `http://YOUR_SERVER_IP:4000`
- Check **Saves** tab
- View upload history

---

## Managing Devices

### Viewing Devices

1. Login to dashboard at `http://YOUR_SERVER_IP:4000`
2. Navigate to **Devices** section
3. See all paired devices with status

### Device Status

| Icon | Status | Meaning |
|------|--------|---------|
| 🟢 | Connected | Daemon running, paired |
| 🔴 | Waiting | App running, not paired |
| ⚪ | Offline | App not running |

### Removing a Device

⚠️ **Warning:** Removing a device does NOT delete saves from cloud

1. Go to **Devices** section
2. Find device to remove
3. Click **"Remove"** button
4. Device can be re-paired later with new code

### Device Names

Devices are identified by their pairing code (6 digits). To track which is which:

1. Note the code when pairing
2. Use consistent codes per device
3. Check device logs to confirm

---

## Viewing Saves

### Dashboard View

1. Login to `http://YOUR_SERVER_IP:4000`
2. Go to **Saves** section
3. Browse all synced saves

### Save Information

Each save shows:
- **Game/filename** - from the file name
- **Device** - which device uploaded it
- **Date** - when last modified
- **Size** - file size

---

## Common Tasks

### "I want to sync saves from my Miyoo to my PC"

1. **On Miyoo:** Launch RetroSync, note pairing code
2. **On PC:** Login to dashboard, enter code
3. **On Miyoo:** Status shows "CONNECTED!"
4. **Play game** on Miyoo, save
5. **Upload** (press A) or wait for auto-sync
6. **On PC:** Start RetroSync daemon
7. **Saves download** automatically

### "I switched devices and want my saves"

1. **On new device:** Launch RetroSync
2. **Pair** using web dashboard
3. **Sync runs** automatically
4. **Saves download** to new device

### "I don't want a device to sync anymore"

1. **On dashboard:** Remove device
2. **On device:** Restart RetroSync app
3. **Generate new code** if needed
4. **Don't pair** - device stays offline

### "Saves aren't syncing"

1. **Check device status** - should show "CONNECTED!"
2. **Check server** - is it running?
3. **Check logs** - any errors?
4. **Try manual upload** - press A on handheld

---

## Tips & Tricks

### Multiple Devices

- Pair each device separately
- Each gets its own 6-digit code
- All sync to same cloud storage

### Save Locations

| Platform | Default Save Path |
|----------|-------------------|
| muOS | `/mnt/SDCARD/RetroArch/saves/` |
| Spruce OS | `/mnt/SDCARD/Saves/` |
| Windows | `%APPDATA%\RetroArch\saves\` |
| macOS | `~/Library/Application Support/RetroArch/saves/` |
| Linux | `~/.config/retroarch/saves/` |

### Battery Life (Handhelds)

- RetroSync uses minimal battery when idle
- Only consumes power when:
  - Checking server status (every 2 seconds)
  - Uploading files (brief periods)

---

## Related Documentation

- [INSTALLATION.md](INSTALLATION.md) - Setup and installation
- [COMPATIBILITY.md](COMPATIBILITY.md) - Supported devices
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
