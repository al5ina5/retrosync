# Paths setup cleanup plan

## Current state (the franken setup)

- **Default paths**: Hardcoded in two places — `client/src/scan_paths.lua` (`getDefaultPaths()`) and `client/watcher.sh` (`locations` array). OS-specific (e.g. OpenEmu on macOS) only in Lua.
- **Custom paths**: Stored in `data/custom_paths.txt` (one path per line). Loaded into `state.customTrackablePaths`; drag-drop adds via `storage.addTrackablePath` → file + mark dirty.
- **Device scan paths (server)**: `DeviceScanPath` table stores path + kind (default|custom) + source (device|user). Heartbeat sends client’s full list and overwrites server; heartbeat response can return server list; client merges “user” custom paths into local state.

So we have: two copies of default paths (Lua + watcher), one custom-path file (Lua + watcher), and server as a third source that can add paths from the dashboard. Sync is: client → server on heartbeat (when dirty / first / hourly); server → client only for “user” custom paths in response.

## Goal

- **One file on device** = single source of truth for “where to scan”.
- **On launch**: OS detected → ensure file is populated (defaults for that OS) → sync to server.
- **When user adds path on device** (e.g. drag-drop): update file → sync to server.
- **When dashboard changes paths**: next client sync (heartbeat or launch) pulls server state and updates the file so device and server stay in sync.

So: file is authoritative on device; server is authoritative when we have a successful sync; after every successful path-sync we write the file from server response so dashboard edits flow back.

## Design

### 1. Single file: `scan_paths.json`

- **Path**: `data/scan_paths.json` (same `DATA_DIR` as today; watcher uses same dir).
- **Shape** (one of two; we’ll pick one):

  **Option A – array of entries (matches API):**

  ```json
  {
    "paths": [
      { "path": "/mnt/sdcard/Saves/saves", "kind": "default" },
      { "path": "/mnt/mmc/MUOS/save/file", "kind": "default" },
      { "path": "/custom/folder", "kind": "custom" }
    ]
  }
  ```

  **Option B – split keys:**

  ```json
  {
    "default": ["/mnt/sdcard/Saves/saves", "/mnt/mmc/MUOS/save/file"],
    "custom": ["/custom/folder"]
  }
  ```

  Recommendation: **Option A** so we don’t need to re-derive `kind` and we can add `source` later if we want. File stays the single source; watcher and server only care about path + kind.

### 2. Where defaults come from (one place)

- **Only** in `client/src/scan_paths.lua`: e.g. `getDefaultPaths()` (or a function that returns entries with `path` + `kind: "default"`). No defaults in watcher.
- On first run / empty file: client writes `scan_paths.json` from OS-detected defaults + empty custom list.

### 3. Client (Lua) flow

- **Startup**:  
  - Load `scan_paths.json`.  
  - If missing or invalid/empty: seed from `scan_paths.getDefaultPaths()` (and optional `getDefaultPathEntries()`), write file, set `scanPathsDirty = true`.  
  - If paired: optionally GET `/api/devices/scan-paths` (with API key) and overwrite file with server response so “dashboard wins” on launch.  
  - From file: fill `state.scanPaths` or keep `state.customTrackablePaths` + default list from file so we don’t branch everywhere. Prefer: **one in-memory list** derived from file, e.g. `state.scanPathEntries = { { path, kind }, ... }`. Then `getScanPaths(state)` just returns that.
- **Drag-drop (or any “add path” on device)**: Append entry to in-memory list, append to `scan_paths.json`, set `scanPathsDirty = true`. Next heartbeat sends full list.
- **Heartbeat**:  
  - If `scanPathsDirty` or first time or periodic (e.g. hourly): send `scanPaths` from file (or from `state.scanPathEntries`).  
  - On success: if response includes `scanPaths`, **overwrite** `scan_paths.json` and in-memory state from response (server is source of truth after sync). Clear `scanPathsDirty`.
- **Remove path on device**: Remove from list and file, set dirty, heartbeat pushes.

So: **read/write everything through `scan_paths.json`**; in-memory state is a cache of that file; after a successful heartbeat that included paths, file = server state.

### 4. Watcher

- **Single source**: Read `data/scan_paths.json`.  
- **No hardcoded paths**: All roots come from the file.  
- **Parsing**: Watcher reads `data/scan_paths.json` via `jq -r '.paths[]?.path // empty'` when jq is available. If jq is not available (e.g. minimal BusyBox), watcher falls back to legacy `custom_paths.txt` then hardcoded defaults.
- **Single file**: Only `scan_paths.json` is used; no `scan_paths_flat.txt`. Client writes only the JSON; watcher reads the JSON with jq.

### 5. Server and dashboard

- **Keep** `DeviceScanPath` and existing heartbeat behavior: device sends full `scanPaths`; server upserts and deletes-by-list so server state = what device sent. Heartbeat response returns `scanPaths`; client overwrites local file from that (implemented: `scan_paths.applyFromServer`).
- **Dashboard**: GET/POST (and later DELETE) `/api/devices/scan-paths` unchanged. POST adds custom path (source: user). When device next heartbeats, it sends its list; server merges; response includes server list; device overwrites file — so dashboard-added path appears on device.
- **Optional**: On client launch when paired, GET `/api/devices/scan-paths` and overwrite file so dashboard changes are applied immediately without waiting for next heartbeat. That way “sync on app launch” is explicit.

### 6. When to sync

- **Device → server**: On heartbeat when `scanPathsDirty` or first time or every 3600s (current logic).
- **Server → device**: On every successful heartbeat that included path sync (response overwrites file). Optionally also on app launch (GET scan-paths and overwrite file).

### 7. Migration

- If `scan_paths.json` is missing but `custom_paths.txt` exists: load custom paths from txt, build path entries (defaults from `getDefaultPaths()` + custom from file), write `scan_paths.json`, then stop reading `custom_paths.txt`.
- Remove all references to `custom_paths.txt` and `CUSTOM_PATHS_FILE` after migration.

### 8. Files to add/change/remove

| Area | Add | Change | Remove |
|------|-----|--------|--------|
| Config | `SCAN_PATHS_FILE` | — | `CUSTOM_PATHS_FILE`, `SCAN_PATHS_FLAT_FILE` |
| scan_paths.lua | Load/save JSON; return entries from file/defaults | getDefaultPaths only; getScanPaths from state built from file | — |
| storage.lua | — | Replace load/save/add custom paths with delegating to scan_paths + file write | loadCustomPaths, saveCustomPaths, addTrackablePath (or move to scan_paths) |
| state.lua | `scanPathEntries` or keep single list | Drop `customTrackablePaths` in favor of one list from file | — |
| api.lua | — | Build payload from file/state; on response overwrite file | — |
| fs.lua | — | findSaveFiles uses path list from state (from file) | — |
| watcher.sh | Read scan_paths.json via jq | Remove hardcoded locations; read only from file(s); fallback custom_paths.txt then defaults | custom_paths.txt, scan_paths_flat.txt |
| main.lua | Load scan_paths at startup; optional GET scan-paths when paired | — | loadCustomPaths |
| UI (connected, custom_paths) | — | Use single path list from state | — |
| Dashboard | — | Optional: DELETE scan path | — |

### 9. Summary

- **One canonical file**: `scan_paths.json` (path + kind per entry).  
- **One file for paths**: `scan_paths.json` only; watcher reads it via jq (no flat file).  
- **Single source of defaults**: `scan_paths.lua` only.  
- **Sync**: Device writes file → heartbeat sends list → server stores; heartbeat response returns list → device overwrites file. Optionally GET scan-paths on launch when paired.  
- **No more**: `custom_paths.txt`, hardcoded paths in watcher, or duplicate default lists.

This gives a single, clear flow: file on device ↔ server, with defaults seeded once from OS and everything else (device or dashboard) synced through that file and heartbeat.
