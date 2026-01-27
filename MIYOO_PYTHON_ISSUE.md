# 🔍 Miyoo Flip - Python Not Installed

## The Issue

The **Miyoo Flip (Spruce OS) does not have Python 3 installed by default**, which RetroSync requires to run.

When you launch RetroSync from the App menu, it will show an error message explaining this.

---

## ✅ Solutions

You have **3 options**:

### Option 1: Install Python on Miyoo Flip (Advanced)

If you want RetroSync on your Miyoo:

1. Visit the **Spruce OS community forums** or Discord
2. Look for Python 3 installation packages for Miyoo Flip
3. Install Python to your device
4. Launch RetroSync again

**Note:** This requires technical knowledge and community support.

---

### Option 2: Use RetroSync on Another Device (Recommended)

RetroSync works perfectly on these devices **without any additional setup**:

#### **Windows PC**
```bash
cd client
pip install -e .
python -m retrosync setup
python -m retrosync start
```

#### **Mac**
```bash
cd client
pip3 install -e .
python3 -m retrosync setup
python3 -m retrosync start
```

#### **Linux**
```bash
cd client
pip3 install -e .
python3 -m retrosync setup
python3 -m retrosync start
```

#### **Anbernic RG35XX+ (muOS)**
muOS typically has Python pre-installed. Copy the client to:
```
/mnt/mmc/MUOS/application/RetroSync/
```

---

### Option 3: Manual Sync (Simple Workaround)

While we work on a Python-free version for Miyoo, you can manually sync:

1. **On your PC**: Run RetroSync client
2. **Copy saves FROM Miyoo**:
   ```bash
   scp -r spruce@10.0.0.94:/mnt/SDCARD/Saves/* ~/local-saves/
   ```
3. Let your PC upload them to the cloud
4. **Copy saves TO Miyoo** from another device later

---

## 🎯 Recommended Setup

**Best setup for now:**

1. ✅ **Server**: Running on your computer (http://192.168.2.1:3000)
2. ✅ **Client on PC**: Syncs your PC saves
3. ⏳ **Miyoo**: Use manual sync for now OR install Python
4. ✅ **Other handhelds**: Works great on muOS devices

---

## 📊 Current Status

| Device | Status | Python Required | Works Now |
|--------|--------|-----------------|-----------|
| Windows PC | ✅ Ready | ✅ Usually installed | ✅ Yes |
| Mac | ✅ Ready | ✅ Usually installed | ✅ Yes |
| Linux | ✅ Ready | ✅ Usually installed | ✅ Yes |
| Anbernic (muOS) | ✅ Ready | ✅ Pre-installed | ✅ Yes |
| **Miyoo Flip** | ⚠️ Needs Python | ❌ Not installed | ⏳ After Python install |

---

## 🔧 Quick Test

Want to check if you have Python on your Miyoo?

SSH into your device:
```bash
ssh spruce@10.0.0.94
python3 --version
```

If you see a version number, you're good!
If not, you'll need to install it first.

---

## 🚀 Next Steps

### For Immediate Use:

1. **Open browser**: http://192.168.2.1:3000
2. **Create account** and login
3. **Add Device** → Get pairing code
4. **On your PC** (not Miyoo):
   ```bash
   cd client
   python -m retrosync setup
   # Enter the pairing code
   python -m retrosync start
   ```
5. **Done!** Your PC saves will sync

### For Miyoo Support:

We're working on a **shell-only version** that won't require Python. Stay tuned!

---

## 📝 Log File

If you launched RetroSync on your Miyoo, check the log:
```bash
ssh spruce@10.0.0.94
cat /mnt/SDCARD/App/RetroSync/retrosync.log
```

This will show you what happened when it tried to launch.

---

## ❓ Questions?

- **Server working?** Yes! ✅ http://192.168.2.1:3000
- **Can I use on PC?** Yes! ✅ Works perfectly
- **Will Miyoo work later?** Yes! After Python install or shell-only version
- **Can I sync manually?** Yes! Use scp/rsync to copy saves

---

**The good news:** RetroSync server is running perfectly!
**For now:** Use it on your PC or other Python-capable devices.
**Future:** We'll create a Python-free Miyoo version! 🎮
