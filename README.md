# RetroSync

Cloud sync service for retro gaming save files across Miyoo devices.

## Project Structure

```
retrosync/
├── dashboard/          # Next.js web dashboard and API
│   ├── src/            # Source code
│   ├── prisma/         # Database schema
│   └── package.json
├── client/             # LOVE2D client app
│   ├── main.lua        # Main game file
│   ├── conf.lua        # LOVE2D config
│   ├── build/          # Build scripts
│   │   └── portmaster/
│   │       ├── build.sh
│   │       └── deploy.sh
│   └── dist/           # Build output
└── package.json        # Root package.json with commands
```

## Quick Start

### Dashboard (Server)

```bash
# Install dependencies
npm run dashboard:install

# Setup database
npm run dashboard:db:generate
npm run dashboard:db:push

# Start development server
npm run dashboard:dev
```

Dashboard will be available at http://localhost:3000

### Client (MIYO Device)

```bash
# Build PortMaster package
npm run client:build

# Deploy to device
npm run client:deploy

# Or build and deploy in one command
npm run deploy
```

## Available Commands

### Dashboard Commands
- `npm run dashboard:dev` - Start development server
- `npm run dashboard:build` - Build for production
- `npm run dashboard:start` - Start production server
- `npm run dashboard:install` - Install dependencies
- `npm run dashboard:db:generate` - Generate Prisma client
- `npm run dashboard:db:push` - Push database schema
- `npm run dashboard:db:migrate` - Run database migrations

### Client Commands
- `npm run client:build` - Build PortMaster package
- `npm run client:deploy` - Deploy to MIYO device
- `npm run client:build:deploy` - Build and deploy

### Root Commands
- `npm run dev` - Start dashboard dev server
- `npm run build` - Build both dashboard and client
- `npm run deploy` - Build and deploy client

## Usage

1. Start the dashboard: `npm run dashboard:dev`
2. Open http://localhost:3000 in your browser
3. Register/login and create a pairing code
4. Build and deploy client: `npm run deploy`
5. Launch RetroSync from Ports menu on your MIYO device
6. Enter the pairing code from the web dashboard
7. Upload save files!

### Client configuration (optional)

- **`data/server_url`** — If present, the client uses this as the API base URL (one line, no trailing slash). Otherwise it uses the built‑in default. Create this file in the app's `data` folder on the device when pointing at a custom server (e.g. production).

### Autostart behavior

RetroSync automatically installs background watcher autostart integration when you first launch the app. The watcher monitors save files and uploads changes to the cloud automatically.

#### spruceOS

When you first launch RetroSync, it automatically integrates with spruce's `networkservices.sh` to start the background watcher on boot. A backup of the original script is created (`.retrosync.bak`) and can be fully restored via `RetroSyncUninstaller.sh` on the device.

#### muOS

RetroSync automatically creates a `retrosync-init.sh` script in `MUOS/init/` (on the SD card containing the `MUOS` folder) so the watcher starts on boot.

**Important Setup Steps:**
1. Launch RetroSync once to install the init script
2. **Enable "User Init Scripts" in muOS settings** (this is required!)
   - Go to muOS Settings → System → User Init Scripts → Enable
3. Reboot your device
4. The watcher should start automatically on boot

**Verifying the Watcher is Running:**

After reboot, check for these files to confirm the watcher started:

- **Heartbeat file**: `/MUOS/init/retrosync-heartbeat.txt`
  - Should contain: `RetroSync init STARTED at [timestamp]`
  - If present, the init script ran successfully
  
- **Init log**: `/MUOS/init/retrosync-init.log`
  - Contains detailed execution logs
  - Look for: `Watcher is running (verified)`
  
- **Watcher log**: `Roms/PORTS/RetroSync/data/watcher.log` (or `ports/RetroSync/data/watcher.log`)
  - Contains watcher runtime logs
  - Should show periodic file checks and uploads

- **Process check**: The watcher process should be running
  - Check with: `ps aux | grep watcher.sh` (if you have SSH access)

**Troubleshooting muOS Autostart:**

If the watcher doesn't start on boot:

1. **Check "User Init Scripts" is enabled**
   - muOS Settings → System → User Init Scripts must be ON
   - This is the most common issue!

2. **Verify init script exists**
   - Check: `/MUOS/init/retrosync-init.sh` exists
   - Should be executable (check permissions)

3. **Check init log for errors**
   - Look at `/MUOS/init/retrosync-init.log`
   - Common errors:
     - `ERROR: RetroSync directory not found` → Path detection failed
     - `ERROR: watcher.sh file not found` → RetroSync not installed correctly
     - `ERROR: watcher.sh exists but is NOT executable` → Permissions issue

4. **Manually test the init script**
   - Run: `sh /MUOS/init/retrosync-init.sh`
   - Check the logs to see what happens

5. **Reinstall autostart**
   - Delete: `Roms/PORTS/RetroSync/data/muos_autostart_installed` (or `ports/RetroSync/data/muos_autostart_installed`)
   - Launch RetroSync once to reinstall
   - Reboot

6. **Check RetroSync installation path**
   - The init script searches common paths: `/mnt/mmc/Roms/PORTS/RetroSync`, `/mnt/sdcard/ports/RetroSync`, etc.
   - If RetroSync is in a non-standard location, the init script may not find it

#### Other Firmwares

RetroSync starts its background watcher for the current session when you launch the app, but does not modify OS boot scripts. The watcher will stop when you exit RetroSync or reboot the device.

### Uninstalling Autostart

To remove autostart integration:

1. Run `RetroSyncUninstaller.sh` from the PortMaster menu (or manually execute it)
2. This will:
   - Stop the watcher process
   - Remove init scripts from `MUOS/init/` (muOS) or restore `networkservices.sh` (spruceOS)
   - Clean up heartbeat and log files
   - Remove install markers

The uninstaller is located at the same level as `RetroSync.sh` in your PortMaster directory.

### Testing on macOS

Ensure `client/watcher.sh` is executable (`chmod +x client/watcher.sh`). Git preserves the execute bit once set.

When you run the Lua client on macOS (`yarn client:test:macos` or `love .` from the `client/` folder):

- **Watcher lifecycle:** The app starts the watcher when it opens and stops it when you quit. You’ll see `watcher: started` and `watcher: exiting` in the watcher log.
- **Log locations** (relative to the app directory, e.g. `client/` when running `love .`):
  - **`data/debug.log`** — Main app log (startup, pairing, uploads, errors). On startup the app also appends contents from `data/watcher.log` here.
  - **`data/watcher.log`** — Watcher daemon log (file discovery, upload attempts, success/failure).
- **Verify uploads via API:** If the client reports uploads but you don’t see them in the dashboard, run:
  ```bash
  ./scripts/check-uploads-api.sh
  ```
  This calls `GET /api/saves` with your device’s API key (from `client/data/api_key`). If it shows saves but the dashboard doesn’t, make sure you’re logged into the dashboard with the **same user account** that paired this device. Use `BASE_URL=http://localhost:3000 ./scripts/check-uploads-api.sh` when testing against a local dashboard.

## License

MIT
