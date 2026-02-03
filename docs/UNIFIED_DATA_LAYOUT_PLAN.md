# Unified Client Data Layout & Build Plan

**Goal:** One folder (LÖVE app data directory) with exactly three things: `config.json`, `logs/`, `watcher/`. No other files or markers. Same structure on every device. Shared, modular code across builds.

---

## 1. Target Directory Layout (Single Source of Truth)

```
<LOVE app data directory>   e.g. getSaveDirectory() → saves/love/retrosync on PortMaster
├── config.json            ← ALL config (settings, deviceHistory, scanPaths)
├── logs/                  ← ALL logs (app + watcher)
│   └── YYYY-MM-DD.log     (app daily logs; rotate by size)
│   └── watcher.log        (watcher daemon log — written inside logs/ by watcher)
└── watcher/               ← watcher runtime + app temp files only
    ├── watcher.pid
    ├── watcher_state.tsv
    ├── watcher.log        ← move here from DATA_DIR root so ALL logs live in logs/ — see below
    └── (temp files: watcher_payload.*.json, http_*.txt, temp_upload_*.bin, etc.)
```

**Clarification:** You said "logs contains ALL logs". So watcher must write its log inside `logs/`, not inside `watcher/`. Revised layout:

```
<LOVE app data directory>
├── config.json
├── logs/
│   ├── YYYY-MM-DD.log     (app daily logs)
│   └── watcher.log        (watcher daemon log — watcher writes here)
└── watcher/
    ├── watcher.pid
    ├── watcher_state.tsv
    └── (temp files only: *.$$.json, *.$$.txt, temp_upload_*.bin, tmp_download_*.bin, http_*.txt, etc.)
```

So: **config.json** (one file, all config), **logs/** (all log files), **watcher/** (pid, state, temp files only). No other files or markers at top level.

---

## 2. config.json Schema (Everything That Is “Config”)

Single JSON file. No separate device_history.json, scan_paths.json, custom_paths.txt, or any marker files.

```json
{
  "serverUrl": "https://retrosync.vercel.app",
  "autostart": false,
  "apiKey": null,
  "deviceName": null,
  "code": null,
  "themeId": "classic",
  "musicEnabled": false,
  "soundsEnabled": false,
  "noPathsMessageDismissed": false,
  "deviceHistory": [],
  "scanPaths": []
}
```

- **deviceHistory:** array of entries (same as current device_history.json). Stored and loaded from config.json.
- **scanPaths:** array of `{ path, kind }` (same as current scan_paths.json). Stored and loaded from config.json. Watcher reads paths from config.json (jq `.scanPaths[]?.path`).

Remove from codebase:

- `config.HISTORY_FILE` → use key in config.json.
- `config.SCAN_PATHS_FILE` → use key in config.json.
- `config.CUSTOM_PATHS_FILE` → migrate into `scanPaths` and remove.

---

## 3. Files to Eliminate (No Other Files / Markers)

| Current file / marker | Action |
|----------------------|--------|
| `device_history.json` | Merge into `config.json` → `deviceHistory` |
| `scan_paths.json` | Merge into `config.json` → `scanPaths` |
| `custom_paths.txt` | Migrate into `config.json.scanPaths`, then remove |
| `autostart_spruce.txt`, `autostart_muos.txt` | Already moving to config; remove all writes/reads |
| `server_url` | Already using config.json `serverUrl`; remove fallback read |
| `spruce_autostart_installed`, `muos_autostart_installed` | Use only config.json `autostart`; remove checks |
| `debug.log` (legacy) | Already migrated into logs/; remove reference |

All launcher/autostart logic: only read/write **config.json** (e.g. `.autostart`, `.serverUrl`). No marker files.

---

## 4. Temp Files → watcher/

All ephemeral files written by the app or watcher must live under **watcher/** so the top level has only config + logs + watcher dir.

| Current location | New location |
|------------------|--------------|
| `DATA_DIR/http_resp.txt`, `http_post.txt`, `http_err.txt`, `curl_exit.txt` | `WATCHER_DIR/` (e.g. `config.WATCHER_DIR`) |
| `DATA_DIR/temp_upload_*.bin` | `WATCHER_DIR/` |
| `DATA_DIR/tmp_download_*.bin` | `WATCHER_DIR/` |
| Watcher: already `WATCHER_DIR/watcher_payload.*.json` etc. | Keep in `watcher/` |

In **config.lua**: keep `M.WATCHER_DIR = M.DATA_DIR .. "/watcher"`. In **http.lua**, **upload.lua**, **download.lua**: use `config.WATCHER_DIR` for these temp files instead of `config.DATA_DIR`.

---

## 5. Logs: All in logs/

- **App:** already writes to `config.LOGS_DIR` (e.g. `DATA_DIR/logs/YYYY-MM-DD.log`). No change.
- **Watcher:** currently writes to `WATCHER_DIR/watcher.log`. Change to **logs/watcher.log** so “logs contains ALL logs”.

So in **watcher.sh**: set something like `LOGFILE="$DATA_DIR/logs/watcher.log"` (and ensure `logs/` exists). In **config.lua** we already have `LOGS_DIR = DATA_DIR .. "/logs"`. Watcher will need `DATA_DIR/logs`; it has `DATA_DIR`, so `LOGFILE="${DATA_DIR}/logs/watcher.log"` and `mkdir -p` that dir.

Result:

- **logs/** = app daily logs + watcher.log only.
- **watcher/** = pid, state, and temp files only.

---

## 6. Shared Build Logic (Modular, No Repeated Code)

Today each build (PortMaster, macOS, Linux, Windows) repeats:

- Resolving DATA dir or subdir (e.g. `saves/love/retrosync` vs `data`).
- Writing a minimal `config.json` (serverUrl, autostart: false) with jq or printf.

Proposal:

- **Single shared script** (e.g. `client/build/shared/write_config_json.sh`) used by all builds:
  - Args: `$1 = directory to write into`, `$2 = server URL` (optional).
  - Creates dir if needed, writes `config.json` with canonical keys (serverUrl, autostart: false). Uses jq if available, else printf.
- **Single shared constant** for the LÖVE data subdir:
  - In one place (e.g. `client/build/shared/vars.sh` or a single line in a script): `RETROSYNC_LOVE_DATA_SUBDIR="saves/love/retrosync"` and identity `retrosync` (must match conf.lua).
  - PortMaster / deploy scripts source or read this so paths are identical everywhere.

Optional: a tiny **shared build script** that each platform’s build.sh calls, e.g.:

- `client/build/shared/ensure_data_dir.sh` — creates `$GAMEDIR/saves/love/retrosync` (or equivalent for desktop).
- `client/build/shared/write_config_json.sh` — writes `config.json` in that dir.

So:

- **config.json** content and path are defined in one place.
- **DATA subdir** (saves/love/retrosync) is defined once; all builds and deploys use it.

---

## 7. Implementation Phases

### Phase 1: config.json holds everything (no extra config files)

1. **config.lua**
   - Remove `HISTORY_FILE`, `SCAN_PATHS_FILE`, `CUSTOM_PATHS_FILE`.
   - Keep only: `CONFIG_FILE`, `LOGS_DIR`, `WATCHER_DIR` (and app constants).
2. **storage.lua**
   - Extend load/save of config.json to include `deviceHistory` and `scanPaths` (read/write from same file). Keep backward compatibility: if `device_history.json` or `scan_paths.json` exist, migrate once into config.json and then use config only.
3. **device_history.lua**
   - Load/save from config (e.g. storage.getConfig().deviceHistory or a small helper that reads config.json and returns/updates deviceHistory). No separate file.
4. **scan_paths.lua**
   - Load/save from config (config.json key `scanPaths`). Migrate from scan_paths.json and custom_paths.txt on first run, then remove those files.
5. **Watcher (watcher.sh)**
   - Read scan paths from config.json only (e.g. `jq -r '.scanPaths[]?.path // empty' "$CONFIG_JSON"`). Remove `scan_paths.json` and `custom_paths.txt` fallbacks after migration.

### Phase 2: All logs in logs/, watcher temp files in watcher/

1. **watcher.sh**
   - Set `LOGFILE="$DATA_DIR/logs/watcher.log"`, `mkdir -p "$DATA_DIR/logs"`. Stop writing to `WATCHER_DIR/watcher.log`.
2. **http.lua, upload.lua, download.lua**
   - Use `config.WATCHER_DIR` for all temp files (http_*.txt, temp_upload_*.bin, tmp_download_*.bin, etc.), not `config.DATA_DIR`.

### Phase 3: No markers; only config.json

1. **storage.lua**
   - Remove all legacy marker reads/writes (autostart_*.txt, spruce_autostart_installed, muos_autostart_installed, server_url file). Migration from markers can one-time set config.json and delete markers.
2. **Launcher (PortMaster build.sh)**
   - Check only `config.json` for autostart (e.g. jq `.autostart == "spruceos"`). Remove checks for `autostart_spruce.txt`, `spruce_autostart_installed`, etc.
3. **Autostart scripts (spruce, muos)**
   - Only update config.json (no sidecar or marker files). Remove any `echo "1" > autostart_*.txt` (or similar).
4. **watcher.sh**
   - Remove `SERVER_URL_FILE` fallback; read serverUrl only from config.json.

### Phase 4: Shared build scripts (modular, no repeated code)

1. Add **client/build/shared/**:
   - `vars.sh`: `RETROSYNC_LOVE_IDENTITY="retrosync"`, `RETROSYNC_LOVE_DATA_SUBDIR="saves/love/retrosync"`.
   - `write_config_json.sh`: writes minimal config.json to `$1` with optional server URL `$2`.
2. **PortMaster build.sh**
   - Source vars, use shared script to create `saves/love/retrosync` and write config.json.
3. **macOS / Linux / Windows build.sh**
   - Use same shared script for writing config.json (and, where applicable, same DATA subdir concept for packaging).
4. **deploy.sh / deploy-muos.sh**
   - Use shared vars for path to config (e.g. `$GAME_NAME/saves/love/retrosync/config.json`).

---

## 8. Final Layout Checklist

After implementation:

- **Top level of app data dir:** only `config.json`, `logs/`, `watcher/`.
- **config.json:** serverUrl, autostart, apiKey, deviceName, code, themeId, musicEnabled, soundsEnabled, noPathsMessageDismissed, deviceHistory, scanPaths. No other config files.
- **logs/:** only log files (e.g. `YYYY-MM-DD.log`, `watcher.log`). No other files in logs/.
- **watcher/:** only watcher.pid, watcher_state.tsv, and temp files. No log files in watcher/.
- **No marker or sidecar files** anywhere (no autostart_*.txt, no server_url, no *_installed, no device_history.json, no scan_paths.json, no custom_paths.txt).
- **Builds:** one shared script (and optional vars) for config path and config.json content; all platforms use it so structure is identical everywhere.

This gives one folder, one structure, all config in config.json, all logs in logs/, and watcher data + temp files in watcher/, with modular shared build code and no repeated logic.
