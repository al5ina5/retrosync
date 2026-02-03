# RetroSync data directory by platform

All app data (config, logs, watcher) lives in **one folder** on each platform. Structure inside that folder is always:

```
<data dir>/
├── config.json
├── logs/
│   ├── YYYY-MM-DD.log
│   └── watcher.log
└── watcher/
    ├── watcher.pid
    ├── watcher_state.tsv
    └── (temp files)
```

The **data directory** itself is the LÖVE save directory (`love.filesystem.getSaveDirectory()`), which depends on platform and identity `retrosync` (set in `client/conf.lua`).

---

## Desktop

| Platform | Data directory |
|----------|-----------------|
| **macOS** | `~/Library/Application Support/LOVE/retrosync` |
| **Windows** | `%USERPROFILE%\AppData\Local\LOVE\retrosync` (e.g. `C:\Users\<user>\AppData\Local\LOVE\retrosync`) |
| **Linux** | `~/.local/share/love/retrosync` (or `$XDG_DATA_HOME/love/retrosync` if `XDG_DATA_HOME` is set) |

---

## Handhelds (PortMaster / SpruceOS / muOS)

The launcher sets `XDG_DATA_HOME="$GAMEDIR/saves"`. LÖVE then uses `$XDG_DATA_HOME/love/<identity>`, so:

| Platform | Data directory |
|----------|-----------------|
| **PortMaster (SpruceOS, muOS, etc.)** | `<game_install_dir>/saves/love/retrosync` |

Typical game install dirs:

- **SpruceOS / common**  
  `/mnt/sdcard/Roms/PORTS/RetroSync`  
  → data: `/mnt/sdcard/Roms/PORTS/RetroSync/saves/love/retrosync`
- **muOS (SD2)**  
  `/mnt/SDCARD/Roms/PORTS/RetroSync` or under `ports/`  
  → data: `<that_path>/saves/love/retrosync`

So on handhelds the data dir is always **`saves/love/retrosync`** under the RetroSync game folder (same as `client/build/shared/vars.sh`: `RETROSYNC_LOVE_DATA_SUBDIR="saves/love/retrosync"`).

---

## Summary

| Platform   | Data folder path |
|-----------|-------------------|
| macOS     | `~/Library/Application Support/LOVE/retrosync` |
| Windows   | `%USERPROFILE%\AppData\Local\LOVE\retrosync` |
| Linux     | `~/.local/share/love/retrosync` (or `$XDG_DATA_HOME/love/retrosync`) |
| PortMaster| `<RetroSync_install_dir>/saves/love/retrosync` |

Inside that folder, only **config.json**, **logs/** and **watcher/** are used.
