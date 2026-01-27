# 🎉 RetroSync Setup Complete!

## ✅ What's Ready

### Server Side
- **Backend**: Running at http://192.168.2.1:3000
- **MinIO Storage**: Running at http://192.168.2.1:9000
- **MinIO Console**: http://192.168.2.1:9001

### Device Side
- **Miyoo Flip**: RetroSync installed at `/mnt/SDCARD/App/RetroSync/`

---

## 📱 How to Use (Super Simple!)

### Step 1: On Your Computer

1. Open your browser and go to:
   ```
   http://192.168.2.1:3000
   ```

2. Click **"Get Started"** and create an account

3. After login, click **"Add Device"**

4. A 6-digit pairing code will appear (like: **123456**)

5. **Keep this browser tab open!**

### Step 2: On Your Miyoo Flip

1. Navigate to **App** menu on your device (or wherever apps are listed)

2. Find and launch **"RetroSync"**

3. On first run, it will:
   - Install dependencies (takes ~2 minutes, one-time only)
   - Auto-detect your Miyoo Flip
   - Ask for the server URL

4. Enter the API URL when prompted:
   ```
   http://192.168.2.1:3000
   ```

5. Select **"Enter code from web dashboard"**

6. Enter the 6-digit code from Step 1

7. Done! RetroSync will start automatically

---

## 🎮 What Happens Next?

### Automatic Syncing
- Save files in `/mnt/SDCARD/Saves/` will sync automatically
- Changes upload immediately
- Downloads check every 5 minutes
- Conflict resolution: newest file wins

### On Your Computer
- View your dashboard: http://192.168.2.1:3000/dashboard
- See sync activity in real-time
- Add more devices with new pairing codes

---

## 🧪 Test It Out!

1. Play a game on your Miyoo
2. Save your progress
3. Check the dashboard - you'll see the upload event!
4. Check MinIO console: http://192.168.2.1:9001 (login: minioadmin/minioadmin)
5. Your save file will be there!

---

## 🔧 Troubleshooting

### Miyoo Can't Connect

Make sure both devices are on the same WiFi network:
- Computer IP: 192.168.2.1
- Miyoo should be on 192.168.2.x or 10.0.0.x network

If on different subnets, use the IP the Miyoo can reach.

### "Python 3 not installed"

Spruce OS needs Python 3. Install it first, then try again.

### "Invalid pairing code"

Codes expire after 15 minutes. Generate a new one in the dashboard.

### Service Not Running

Restart everything:
```bash
./stop-dev.sh
./start.sh
```

---

## 📊 Management Commands

### Stop Services
```bash
docker-compose down
```

### View Logs
```bash
docker-compose logs -f backend
```

### Restart
```bash
./start.sh
```

---

## 🎯 Next Steps

### Add More Devices

1. Generate a new pairing code in the dashboard
2. Run the setup on your other device:
   ```bash
   cd client
   python -m retrosync setup
   ```
3. Enter the pairing code
4. All devices will sync automatically!

### Supported Devices

- ✅ Miyoo Flip (Spruce OS) - **INSTALLED**
- Anbernic RG35XX+ (muOS)
- Windows PC
- Mac
- Linux

---

## 🔗 Important URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Dashboard | http://192.168.2.1:3000 | Your account |
| MinIO Console | http://192.168.2.1:9001 | minioadmin / minioadmin |
| API Base | http://192.168.2.1:3000/api | - |

---

## 📝 Configuration Files

### Server
- `.env` - Environment variables
- `backend/prisma/dev.db` - User database
- Docker volumes for MinIO data

### Miyoo Device
- `/mnt/SDCARD/App/RetroSync/` - Installed app location
- `/mnt/SDCARD/RetroSync/config.json` - Device configuration
- `/mnt/SDCARD/Saves/` - Watched save directory

---

## 🎊 You're All Set!

Just:
1. Open http://192.168.2.1:3000 in your browser
2. Launch RetroSync from APPS on your Miyoo
3. Start gaming!

Your saves will sync automatically across all your devices! 🚀

---

## ❓ Need Help?

- Check logs: `docker-compose logs -f`
- MinIO storage browser: http://192.168.2.1:9001
- Project docs: `/docs` directory
- Issues: Create an issue in the repository

---

**Enjoy RetroSync! 🎮✨**
