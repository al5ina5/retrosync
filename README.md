# RetroSync

**Download (latest):** [Windows](https://github.com/alsinas/retrosync/releases/latest/download/retrosync-windows.zip) · [macOS](https://github.com/alsinas/retrosync/releases/latest/download/retrosync-macos.zip) · [Linux](https://github.com/alsinas/retrosync/releases/latest/download/retrosync-linux.zip) · [PortMaster](https://github.com/alsinas/retrosync/releases/latest/download/retrosync-portmaster.zip) · [.love](https://github.com/alsinas/retrosync/releases/latest/download/retrosync.love)

RetroSync is a cloud sync service for retro game battery saves that includes a web dashboard and a LÖVE (Lua) client for handhelds and desktop. This README is derived from the codebase behavior and structure, not from other docs.

**What It Does**

RetroSync keeps `.sav` and `.srm` battery saves in sync across devices. Devices upload saves to the server, the server stores and versions them, and devices download newer saves back to their local paths. The web dashboard is where users create accounts, pair devices, manage saves, and upgrade plans.

**High-Level Architecture**

1. Web dashboard + API server in `dashboard/` using Next.js App Router.
2. Database via Prisma (PostgreSQL) stores users, devices, saves, versions, locations, and sync logs.
3. Object storage via S3-compatible API (AWS S3 or MinIO) stores save bytes.
4. LÖVE client in `client/` handles pairing, manual sync, and UI on retro handhelds or desktop.
5. Background watcher in `client/watcher.sh` polls the filesystem and uploads changes in the background on supported platforms.
6. Stripe integration provides a paid subscription tier ($6/mo) and a billing portal.

**End-User UX (Web Dashboard)**

Primary pages live at `/` and are styled with a Game Boy inspired theme. There is also a secondary, older `/dashboard/*` UI with a different visual style that is still wired to the same API.

1. Home (`/`)
The landing page explains the product and points to device pairing.

2. Auth (`/auth`)
Users can register or log in. Registration enforces a strong password (min 10 chars, upper/lower/digit). Login uses JWT stored in localStorage.

3. Devices (`/devices`)
Users enter the 6-character code shown on the device to pair. Paired devices are listed. The UI includes a download section for client builds (currently UI-only, links are placeholders).

4. Saves (`/saves`)
Shows each save, last upload time, device/location counts, and locations grouped by device. Users can download the latest version, or toggle sync strategy between `shared` and `per_device`.

5. Account (`/account`)
Users can update display name, email, and password, open the Stripe portal (paid users), and delete their account (with password confirmation).

6. Upgrade (`/upgrade`, `/upgrade/complete`)
Paid plan checkout is done via Stripe Checkout. After completion, the app verifies the session and upgrades the user to `paid`.

7. Download (`/download`)
A public-facing download page for clients. The buttons are currently non-functional placeholders in code.

8. Client Spec (`/client`)
A pixel-perfect visual spec for the LÖVE client UI. It is intentionally used as the design reference for `client/src/ui/*.lua`.

**End-User UX (Device Client)**

The LÖVE app is a Game Boy–styled UI with d-pad or keyboard navigation. There is no text entry on the device UI; pairing and configuration are done via the dashboard or file-based config.

1. Pairing screen
The device requests a 6-character code from `/api/devices/code` and displays it. It then polls `/api/devices/status` until the user links the code on the dashboard, at which point it receives an API key and device name.

2. Home screen
Menu options are `Sync`, `Recent`, and `Settings` with animated title. The device name is shown at the bottom.

3. Sync screen
Shows uploaded and downloaded counts, plus rotating status lines. Upload and download happen in phases so the UI stays responsive.

4. Recent screen
Lists recent saves pulled from the API, with a simple list UI.

5. Settings screen
Toggles for music, sounds, theme, background process, and unpair. The background process toggle runs install/uninstall scripts and shows a loading overlay during execution.

6. Unpair confirmation
A centered confirmation screen. Selecting Yes clears local API key/code and returns to pairing.

7. Desktop drag-and-drop overlay
On macOS/Windows/Linux, dropping a folder or file onto the window adds a custom sync path and shows an overlay.

**Data Model (Prisma)**

Key tables and relationships:

- `User`: account with email, password hash, subscription tier, Stripe customer ID.
- `Device`: paired device with API key, type, and last sync time.
- `PairingCode`: 6-character device pairing code, can be linked to a user or device and expires after 15 minutes.
- `Save`: logical save per user. Uses `saveKey` (basename, extension-stripped) and a display name.
- `SaveLocation`: per-device local path mapping for a save. Stores the exact local path (including extension).
- `SaveVersion`: a versioned upload for a save, with content hash, size, local modified time, and S3 storage key.
- `SyncLog`: audit trail of upload/download actions.

**Save Identity and Matching**

Save identity is normalized to avoid `.sav` vs `.srm` mismatches and path differences.

1. The server strips `.sav` and `.srm` from filenames to produce a canonical `saveKey`.
2. The server uses the basename (not full path) to build `saveKey` so matching works across different emulator folders.
3. If no match is found by `saveKey`, the server tries to match by `contentHash` to handle ROM renames.
4. The server de-duplicates uploads by `contentHash` and does not store duplicate versions.

**Sync Strategy**

RetroSync supports two strategies per save.

1. `shared` (default)
One canonical version is shared across all devices. This is the only strategy included in the download manifest.

2. `per_device`
Each device keeps its own version history and does not sync across devices. These saves are excluded from the download manifest.

**Upload Flow (Device to Server)**

1. Client discovers `.sav` and `.srm` files in known locations plus any custom paths.
2. Client compares local mtime/size to the server manifest to skip uploads that are already synced.
3. Client uploads as base64 JSON to `/api/sync/files` with `localPath` and `localModifiedAt`.
4. Server normalizes paths, strips `.sav/.srm` from keys, and creates `Save`, `SaveLocation`, and `SaveVersion` records.
5. Server rejects uploads that are older than the current device version or unchanged within tolerance.
6. Bytes are stored in S3 under `{userId}/saves/{saveId}/versions/{saveVersionId}`.

**Download Flow (Server to Device)**

1. Client fetches `/api/sync/manifest`.
2. Manifest includes mapped saves for the device and also unmapped shared saves for awareness.
3. Client compares cloud version time/size to local file and builds a download queue.
4. Client downloads each file from `/api/sync/download?saveVersionId=...` using its API key.
5. Downloads are written via a temp file, existing files are backed up to `.bak`, and mtime is set to the cloud value.

**Background Watcher (Polling Sync)**

`client/watcher.sh` runs as a separate polling daemon for platforms that support it. It scans known save directories and custom paths, compares mtime and size against a local state file, and uploads changed files. It uses backoff when idle, debounces writes, and keeps state if uploads fail so changes are retried.

Supported autostart behaviors:

1. macOS uses LaunchAgent install/uninstall scripts and stores an install marker.
2. muOS and Spruce use their respective autostart scripts and markers.
3. The LÖVE settings menu toggles these scripts on or off.

**Web API Overview**

Authentication:

- Web dashboard uses JWT in the `Authorization: Bearer` header.
- Devices use an API key in the `X-API-Key` header.

Key endpoints:

- `/api/auth/register`, `/api/auth/login`
- `/api/devices/code`, `/api/devices/status`, `/api/devices/pair`, `/api/devices/auto-pair`
- `/api/sync/files`, `/api/sync/manifest`, `/api/sync/download`, `/api/sync/heartbeat`, `/api/sync/log`
- `/api/saves`, `/api/saves/download`, `/api/saves/set-sync-strategy`, `/api/saves/set-sync-mode`
- `/api/account` (GET/PATCH/DELETE)
- `/api/upgrade/checkout`, `/api/upgrade/verify`, `/api/upgrade/portal`, `/api/upgrade/webhook`

**Local Development**

From the repo root:

1. `npm run dashboard:install`
2. `npm run dashboard:db:generate`
3. `npm run dashboard:db:push`
4. `npm run dashboard:dev`

Client build and deploy:

1. `npm run client:build`
2. `npm run client:deploy`

**Environment Variables (Server)**

The dashboard server expects the following environment variables based on code usage.

- `DATABASE_URL` for Prisma.
- `JWT_SECRET` for JWT signing (required in production).
- `S3_ENDPOINT` or `MINIO_ENDPOINT`
- `S3_ACCESS_KEY_ID` or `MINIO_ROOT_USER`
- `S3_SECRET_ACCESS_KEY` or `MINIO_ROOT_PASSWORD`
- `S3_BUCKET` or `MINIO_BUCKET`
- `AWS_REGION`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` or `STRIPE_PUBLISHABLE_KEY`

**Repository Map**

- `dashboard/` Next.js app and API
- `dashboard/src/app/api/` API routes
- `dashboard/prisma/schema.prisma` data model
- `client/` LÖVE app and watcher scripts
- `client/src/` Lua modules for UI, sync, and storage
- `client/watcher.sh` background polling daemon
- `scripts/` helper scripts for testing and deployment

**Notes on UI Ownership**

The dashboard has two sets of pages:

- `/` + `/devices` + `/saves` + `/account` use the Game Boy visual theme.
- `/dashboard/*` pages use a separate, Vercel-like theme and are still wired to the same API.

If you are redesigning or consolidating the UI, both routes are part of the current app surface.

**License**

MIT
