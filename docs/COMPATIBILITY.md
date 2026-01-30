# RetroSync Compatibility Guide

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [Supported Devices](#supported-devices)
2. [Supported Operating Systems](#supported-operating-systems)
3. [Save File Types](#save-file-types)
4. [Save File Locations](#save-file-locations)
5. [Emulator Compatibility](#emulator-compatibility)
6. [File System Requirements](#file-system-requirements)
7. [Known Limitations](#known-limitations)

---

## Supported Devices

### Handheld Gaming Devices

| Device | OS | Status | Notes |
|--------|-----|--------|-------|
| Anbernic RG35XX+ | muOS | ✅ Supported | Primary target |
| Anbernic RG35XX H | muOS | ✅ Should Work | Same OS |
| Anbernic RG40XX V | muOS | ✅ Should Work | Same OS |
| Miyoo Flip | Spruce OS | ✅ Supported | Python/LÖVE/Shell clients |
| Miyoo Mini | Spruce OS | ⚠️ Limited | Small screen |
| PowKiddy RGB30 | ArkOS | ⚠️ Not Tested | May work |
| Analogue Pocket | MiSTer | ❌ Not Supported | Different architecture |
| Steam Deck | SteamOS | ⚠️ Not Tested | Should work (Linux) |

### Desktop/PC Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Windows 10+ | ✅ Supported | Python client |
| Windows 11 | ✅ Supported | Python client |
| macOS 11+ (Intel) | ✅ Supported | Python client |
| macOS 11+ (Apple Silicon) | ✅ Supported | Python client |
| Linux (Ubuntu 20.04+) | ✅ Supported | Python client |
| Linux (Arch) | ✅ Supported | Python client |
| Linux (Fedora) | ✅ Supported | Python client |

### Single-Board Computers

| Device | Status | Notes |
|--------|--------|-------|
| Raspberry Pi 4/5 | ⚠️ Should Work | Linux install |
| NVIDIA Jetson | ⚠️ Not Tested | Linux install |
| Odroid N2+ | ⚠️ Should Work | Linux install |

---

## Supported Operating Systems

### For Devices

| OS | Version | Client Type | Notes |
|----|---------|-------------|-------|
| muOS | Latest | Python | Primary platform |
| Spruce OS | Latest | Python/LÖVE/Shell | Multiple options |
| ArkOS | Latest | ⚠️ Not Tested | May work with Python |
| TheArkOS | Latest | ⚠️ Not Tested | May work with Python |

### For PCs

| OS | Version | Python | Docker |
|----|---------|--------|--------|
| Windows | 10, 11 | 3.9+ | ✅ |
| macOS | 11+ (Intel/Apple Silicon) | 3.9+ | ✅ |
| Ubuntu | 20.04, 22.04, 24.04 | 3.9+ | ✅ |
| Debian | 11, 12 | 3.9+ | ✅ |
| Fedora | 38, 39, 40 | 3.9+ | ✅ |
| Arch Linux | Rolling | 3.9+ | ✅ |
| openSUSE | Leap, Tumbleweed | 3.9+ | ✅ |

---

## Save File Types

### Supported Extensions

| Extension | Type | Description | Sync Behavior |
|-----------|------|-------------|---------------|
| `.srm` | Battery Save | SRAM/Flash memory save | ✅ Always sync |
| `.sav` | Battery Save | Generic save file | ✅ Always sync |
| `.eep` | Battery Save | EEPROM save | ✅ Always sync |
| `.fla` | Battery Save | Flash save | ✅ Always sync |
| `.state` | Save State | Emulator save state | ⚠️ Configurable |
| `.st` | Save State | Alternative save state | ⚠️ Configurable |
| `.mpk` | Controller Pak | N64 controller memory | ✅ Always sync |
| `.rtc` | RTC Save | Real-time clock data | ✅ Always sync |
| `.dss` | Save State | DeSmuME save | ⚠️ Configurable |
| `.dsv` | Battery Save | DeSmuME battery | ✅ Always sync |
| `.sps` | Save State | PCSX2 save state | ⚠️ Configurable |
| `.gci` | Save State | GameCube save | ✅ Always sync |
| `.raw` | Memory Card | PS1 memory card | ✅ Always sync |

### File Size Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Maximum file size | 100MB | Per file |
| Typical save size | 1KB - 1MB | Most games |
| Large save states | 10-50MB | Some PS1/N64 |
| Maximum total storage | 1GB (Free tier) | Pro tier: Unlimited |

### Not Supported

❌ **These files are NOT synced:**

- ROM files (`.iso`, `.gba`, `.nes`, etc.)
- BIOS files (`.bin`, `.bios`)
- Cheat files (`.cht`, `.cheats`)
- Configuration files (`.cfg`, `.ini`)
- Screenshots (`.png`, `.jpg`)
- Video recordings (`.mp4`, `.mkv`)
- Shader files (`.glsl`, `.slang`)
- Database files (`.db`, `.json`)

---

## Save File Locations

### muOS (Anbernic RG35XX+)

#### Default Locations

| Emulator/Cores | Save Location |
|----------------|---------------|
| RetroArch (all cores) | `/mnt/SDCARD/RetroArch/saves/` |
| Genesis Plus GX | `/mnt/SDCARD/Saves/genesis/` |
| Picodrive | `/mnt/SDCARD/Saves/picodrive/` |
| PPSSPP | `/mnt/SDCARD/PPSP/savedata/` |
| MAME 2000 | `/mnt/SDCARD/Saves/mame2000/` |
| MAME 2003 | `/mnt/SDCARD/Saves/mame2003/` |
| FBNeo | `/mnt/SDCARD/Saves/fbneo/` |
| ScummVM | `/mnt/SDCARD/Saves/scummvm/` |

#### Common Pattern

```
/mnt/SDCARD/
├── RetroArch/
│   └── saves/
│       ├── genesis_plus_gx/
│       │   └── "Game Name.srm"
│       ├── picodrive/
│       │   └── "Game Name.srm"
│       └── snes9x/
│           └── "Game Name.srm"
└── Saves/
    ├── genesis/
    ├── picodrive/
    └── ppsspp/
        └── "GameID/"
            └── SAVE_DATA_DIR/
                └── *.sav
```

### Spruce OS (Miyoo Flip)

#### Default Locations

| Emulator/Cores | Save Location |
|----------------|---------------|
| RetroArch (all cores) | `/mnt/SDCARD/RetroArch/saves/` |
| MiyooOS Cores | `/mnt/SDCARD/Saves/` |
| PocketStation | `/mnt/SDCARD/Saves/pocketsta/` |

#### Common Pattern

```
/mnt/SDCARD/
├── RetroArch/
│   └── saves/
│       └── "Core Name"/
│           └── "Game Name.srm"
└── Saves/
    ├── "Game Name.srm"
    └── "Game Name.state"
```

### PC (Windows)

| Emulator | Save Location |
|----------|---------------|
| RetroArch | `%APPDATA%\RetroArch\saves\` |
| RetroArch (standalone) | `%APPDATA%\<emulator>\saves\` |
| PCSX2 | `%USERPROFILE%\Documents\PCSX2\saves\` |
| Dolphin | `%USERPROFILE%\Documents\Dolphin Emulator\GC\` |
| RPCS3 | `%USERPROFILE%\Documents\PS3\saves\` |
| Citra | `%USERPROFILE%\Documents\Citra\sdmc\` |
| Yuzu | `%USERPROFILE%\Documents\Yuzu\load\` |
| Cemu | `%USERPROFILE%\Documents\Cemu\mlc01\` |
| PPSSPP | `%USERPROFILE%\Documents\PPSSPP\PSP\SAVEDATA\` |

### PC (macOS)

| Emulator | Save Location |
|----------|---------------|
| RetroArch | `~/Library/Application Support/RetroArch/saves/` |
| PCSX2 | `~/Documents/PCSX2/saves/` |
| Dolphin | `~/Documents/Dolphin Emulator/GC/` |
| RPCS3 | `~/Documents/PS3/saves/` |
| Citra | `~/Library/Application Support/Citra/sdmc/` |
| Yuzu | `~/Library/Application Support/Yuzu/load/` |

### PC (Linux)

| Emulator | Save Location |
|----------|---------------|
| RetroArch | `~/.config/retroarch/saves/` |
| PCSX2 | `~/.local/share/PCSX2/saves/` |
| Dolphin | `~/.local/share/dolphin-emu/GC/` |
| RPCS3 | `~/.local/share/rpcs3/saves/` |
| Citra | `~/.local/share/citra/sdmc/` |
| Yuzu | `~/.local/share/yuzu/load/` |

---

## Emulator Compatibility

### Full Compatibility

These emulators work perfectly with RetroSync:

| Emulator | Systems | Save Format | Notes |
|----------|---------|-------------|-------|
| RetroArch + cores | Multiple | .srm, .state | Best compatibility |
| Genesis Plus GX | Genesis, Master System, Game Gear | .srm | Industry standard |
| Picodrive | Genesis, 32X, Sega CD | .srm | Good compatibility |
| PPSSPP | PSP | .sav | Full save support |
| Snes9x | SNES | .srm | Perfect compatibility |
| FBNeo | Arcade | .fr | Fight game saves |
| MAME 2003 | Arcade | .hi | High score saves |

### Partial Compatibility

These emulators work but may have quirks:

| Emulator | Systems | Save Format | Notes |
|----------|---------|-------------|-------|
| PCSX2 | PS2 | .pcs2, .mcd | Memory card support |
| Dolphin | GameCube, Wii | .gci, .raw | Memory card files |
| RPCS3 | PS3 | .psv | Save data directories |
| Citra | 3DS | .sav, .av | Physical save files |
| Yuzu | Switch | .save | Title-based saves |

### Emulator-Specific Notes

#### RetroArch Cores

| Core | Systems | Save Extension | State Extension |
|------|---------|----------------|-----------------|
| genesis_plus_gx | Genesis | .srm | .state |
| snes9x | SNES | .srm | .state |
| fceumm | NES | .srm | .state |
| gambatte | Game Boy | .srm | .state |
| mgba | Game Boy Advance | .srm | .state |
| ppsspp | PSP | .max | .state |
| dolphin | GameCube | .gci | .state |
| pcsx2 | PS2 | .pcs2 | .state |

#### Save State Considerations

⚠️ **Important:** Save states (`*.state`) are:

- **Good for:** Quick progress points, testing
- **Bad for:** Cross-device compatibility (may not work on different cores/versions)
- **Recommendation:** Sync battery saves (`.srm`) always, sync states optionally

---

## File System Requirements

### Device Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Free space | 50MB | 100MB+ |
| File system | FAT32/exFAT | exFAT |
| Write speed | 1MB/s | 5MB/s+ |

### PC Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Free space | 100MB | 500MB+ |
| File system | Any | NTFS/APFS/ext4 |

### File Naming

✅ **Supported:**
- Alphanumeric characters
- Spaces (avoid if possible)
- Common punctuation (hyphens, underscores, parentheses)
- Unicode characters (limited support)

❌ **Not Supported:**
- Path separators (`/`, `\`)
- Special characters (`*`, `?`, `<`, `>`, `|`, `:`)
- Control characters (ASCII 0-31)
- Reserved names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`)

---

## Known Limitations

### Current Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No Delta Sync | Larger bandwidth usage | Use save files, not states |
| Last-Write-Wins Only | Conflicts overwrite | Manual rename for both versions |
| No Selective Sync | All saves sync | Exclude by extension in config |
| No Cloud Management | Can't organize saves | Delete via dashboard |
| No Version History | Only latest version | Manual backup before overwrite |

### Platform-Specific Issues

| Platform | Issue | Status |
|----------|-------|--------|
| Miyoo Flip - Shell Client | Incomplete implementation | Need development |
| macOS - ARM | Rosetta may be needed | Use Python 3.9+ ARM build |
| Windows - Path length | Long paths fail | Use short paths |
| Linux - Snap | FUSE issues | Use .deb or pip |

### Browser Compatibility

| Browser | Status | Notes |
|---------|--------|-------|
| Chrome 90+ | ✅ Full Support | Recommended |
| Firefox 90+ | ✅ Full Support | Recommended |
| Safari 14+ | ✅ Full Support | Minor UI differences |
| Edge 90+ | ✅ Full Support | Same as Chrome |
| IE 11 | ❌ Not Supported | Not compatible |

---

## Future Compatibility

### Planned Support

These platforms are on the roadmap:

| Platform | Target | Notes |
|----------|--------|-------|
| Anbernic RG Cube | Q2 2026 | muOS support |
| Steam Deck | Q3 2026 | Desktop mode |
| Odin 2 | Q3 2026 | Android-based |
| iOS | 2027 | Sideloaded app |

### Feature Requests

To request support for:
- New devices → Open GitHub issue
- New emulators → Open GitHub issue
- New features → Open GitHub discussion

---

## Related Documentation

- [Installation Guide](INSTALLATION.md)
- [Usage Guide](USAGE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Developer Guide](DEVELOPER.md)
