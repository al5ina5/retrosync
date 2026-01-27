RetroSync for Miyoo Flip (Spruce OS)
=======================================

INSTALLATION
------------

1. Copy this entire folder to your SD card:
   /mnt/SDCARD/App/RetroSync/

2. The folder structure should look like:
   /mnt/SDCARD/App/RetroSync/
   ├── launch.sh
   ├── retrosync/
   └── README.txt

3. Your Miyoo will automatically detect it in the App menu


FIRST RUN
---------

1. Launch "RetroSync" from your App menu

2. On first run, it will:
   - Install Python dependencies (one-time, takes ~2 min)
   - Auto-detect your Miyoo Flip
   - Ask for your RetroSync server URL

3. You'll need:
   - Your computer's IP address (shown when you run ./start.sh)
   - A pairing code from the web dashboard

4. Enter the pairing code when prompted

5. RetroSync will start automatically!


PAIRING STEPS
-------------

On your computer:
1. Run: ./start.sh
2. Open the URL shown (e.g., http://192.168.1.100:3000)
3. Register/login
4. Click "Add Device"
5. Copy the 6-digit code

On your Miyoo:
1. Launch RetroSync from Apps
2. Enter the code when prompted
3. Done! Your saves will now sync automatically


SAVE FILE LOCATIONS
-------------------

RetroSync will automatically watch these folders:
- /mnt/SDCARD/Saves/
- /mnt/SDCARD/RetroArch/.retroarch/saves/

Any save files (.srm, .sav, .state) will sync automatically!


TROUBLESHOOTING
---------------

"Python 3 not installed"
→ Install Python 3 for Spruce OS first

"Failed to connect to server"
→ Check your computer's IP address
→ Make sure your Miyoo is on the same WiFi network
→ Verify RetroSync is running (./start.sh)

"Invalid pairing code"
→ Codes expire after 15 minutes
→ Generate a new code in the web dashboard

Configuration is saved to: /mnt/SDCARD/RetroSync/config.json


SUPPORT
-------

For issues and updates:
https://github.com/anthropics/retrosync
