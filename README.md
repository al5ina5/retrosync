# RetroSync

RetroSync is a cloud sync service for retro gaming save files. It ships a desktop/handheld client (LOVE + Lua), a web dashboard (Next.js), a Postgres metadata store (Prisma), and S3-compatible object storage for the save binaries.

This README is generated from the current codebase. It does not rely on the docs folder.

## Product summary

RetroSync keeps battery saves in sync across devices. The basic flow is:

1. User creates an account in the web dashboard.
2. Device launches the client and requests a pairing code.
3. User enters that code in the dashboard to link the device.
4. Device receives an API key and syncs saves.
5. Saves are uploaded to the server, then the device downloads newer versions.
6. The dashboard shows devices, saves, and account/billing.

## Architecture at a glance

- Client: LOVE 11.x app in Lua (`client/`).
- Background watcher: shell script that polls for save changes (`client/watcher.sh`).
- Web app + API: Next.js App Router (`dashboard/`).
- Database: Postgres with Prisma (`dashboard/prisma/schema.prisma`).
- Storage: S3-compatible bucket (MinIO supported via env fallbacks).
- Billing: Stripe subscriptions ($6/mo) and upgrade limits.

## Client details (client/)

### Data and config

- Uses the LOVE save directory as the data root. On desktop this is a user-writable directory like:
  - macOS: `~/Library/Application Support/LOVE/retrosync`
  - Windows: `%LOCALAPPDATA%\LOVE\retrosync`
  - Linux: `~/.local/share/love/retrosync`
- Single config file: `config.json` (API key, server URL, theme, scan paths, device history, etc.).
- Logs are written to `logs/` and rotated when large.
- Runtime temp files live under `watcher/`.

### UX screens

The client UI is a fixed 640x480 design with a Game Boy palette. States include:

- Pairing code screen (shows 6-char code and polling status).
- Home screen: Sync, Recent, Settings.
- Sync progress screen (upload + download counts).
- Recent saves list (pulled from the server).
- Settings list (music/sound/theme/background process/unpair).
- Confirm dialog (unpair).
- Loading overlay (background process toggles).
- Drag-and-drop overlay (desktop only; add scan paths).

Note: The client does not support text input or file browsing dialogs. Custom paths are added via drag-and-drop (desktop) or from the dashboard device settings.

### Scan paths

- A single list of scan paths is stored in `config.json` (`scanPaths`).
- Default suggestions are OS-specific (muOS, SpruceOS, OpenEmu).
- The client only syncs default paths that actually exist on the device.
- Scan paths are sent to the server during heartbeat and can be updated by the dashboard.

### Sync behavior

- Only battery saves are synced: `.sav` and `.srm` (no save states, no `.bak`).
- Sync order: upload first, then download newer cloud versions.
- The client uses local mtime + size to decide whether to upload or download.
- Uses extension-agnostic matching: `.sav` and `.srm` are treated as the same logical save key.
- For files without valid mtimes, size matching is used to avoid unnecessary sync.

### Background watcher

- `client/watcher.sh` is a polling daemon (busybox friendly) that scans for changes and uploads.
- It uses the same config file and API key as the client.
- It can be installed as an autostart service:
  - macOS LaunchAgent
  - muOS (PortMaster)
  - spruceOS

## Server and API (dashboard/)

### Auth and account

- JWT-based auth (`Authorization: Bearer <token>`).
- Endpoints: `/api/auth/register`, `/api/auth/login`, `/api/account`.
- Passwords are hashed with bcrypt.
- Login has basic in-memory rate limiting per email.

### Pairing flow

- Device requests code: `POST /api/devices/code`.
- User links code to account: `POST /api/devices/pair` (dashboard).
- Device polls for pairing: `POST /api/devices/status`.
- Alternate flows exist for deviceId-based pairing and auto-pairing.

### Sync and storage

- Upload: `POST /api/sync/files` (base64 payload).
- Manifest: `GET /api/sync/manifest` (per-device paths, latest versions).
- Download: `GET /api/sync/download?saveVersionId=...` (raw bytes).
- Heartbeat: `POST /api/sync/heartbeat` (scan paths + lastSync).
- Logs: `POST /api/sync/log`.

### Save management

- List saves: `GET /api/saves`.
- Download from dashboard: `GET /api/saves/download?filePath=...`.
- Delete save: `DELETE /api/saves?saveId=...`.
- Sync strategy per save: `PATCH /api/saves/set-sync-strategy`.
- Sync mode per location (stored, not enforced by client yet): `PATCH /api/saves/set-sync-mode`.

### Upgrade and limits

- Checkout: `POST /api/upgrade/checkout`.
- Verify after checkout: `GET /api/upgrade/verify?session_id=...`.
- Stripe portal: `POST /api/upgrade/portal`.
- Webhook: `POST /api/upgrade/webhook`.

### Debug

- `/api/debug/db-test` and `/api/debug/s3-test` are guarded in production by `DEBUG_TOKEN`.

## Data model (Prisma)

- User
  - subscriptionTier (`free` or `paid`)
  - stripeCustomerId
- Device
  - apiKey
  - scan paths (DeviceScanPath)
- Save
  - saveKey (extension-agnostic)
  - displayName
  - syncStrategy (`shared` or `per_device`)
- SaveLocation
  - device-specific path mapping
  - syncMode (`sync`, `upload_only`, `disabled`)
- SaveVersion
  - contentHash, byteSize, localModifiedAt, uploadedAt
- SyncLog
- PairingCode
- DownloadEvent

## Plans and limits (from code)

- Free tier:
  - Max devices: 2
  - Max shared saves: 3
  - Dashboard downloads per week: 5
- Paid tier:
  - Unlimited devices, saves, and downloads
- Stripe price: $6/month (see `dashboard/src/lib/stripe.ts`).

## Dashboard UX

Public pages

- `/` Home
- `/how-it-works` Product story
- `/download` Client downloads
- `/auth` Sign in / Sign up

Authenticated pages

- `/devices` Pair device, list devices, manage scan paths, download clients
- `/saves` View saves, download, toggle shared/per-device
- `/account` Profile, subscription, delete account
- `/upgrade` Upgrade to Pro
- `/onboard` Step-by-step onboarding

Design reference

- `/client` is a pixel-perfect spec for the LOVE client UI.

## Local development

Dashboard

- Install deps: `cd dashboard && npm install`
- Prisma: `npx prisma generate`, `npx prisma db push` or `npx prisma migrate dev`
- Run dev server: `npm run dashboard:dev`

Root scripts (see `package.json`)

- `npm run dev` -> dashboard dev server
- `npm run build` -> dashboard build + client build
- `npm run deploy:vercel` -> Vercel deploy (uses `scripts/vercel-env.mjs`)

Storage

- `dashboard/src/lib/s3.ts` supports S3 or MinIO via env vars.
- `docker-compose.yml` includes a MinIO service, but references a `./backend` directory that is not present in this repo. Treat it as stale unless restored.

## Environment variables (server)

Required in production by code paths:

- `DATABASE_URL`
- `JWT_SECRET`
- `S3_ENDPOINT` or `MINIO_ENDPOINT`
- `S3_ACCESS_KEY_ID` or `MINIO_ROOT_USER`
- `S3_SECRET_ACCESS_KEY` or `MINIO_ROOT_PASSWORD`
- `S3_BUCKET` or `MINIO_BUCKET`
- `AWS_REGION`

Stripe (optional, enables billing):

- `STRIPE_SECRET_KEY`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` or `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET` (for webhook verification)

Optional:

- `DEBUG_TOKEN` (protects debug endpoints in production)
- `NEXT_PUBLIC_API_URL` (used by deploy scripts)

## Repo layout

- `client/` LOVE client, assets, and build scripts
- `dashboard/` Next.js app, API routes, Prisma schema
- `scripts/` helper scripts (deploy, tests)
- `docs/` notes and plans (not authoritative)

