# Client UX policy

## No typing or file browsing on device

**All text input and file/path picking happens on the web dashboard.** The Lua client runs on handhelds and embedded devices (Miyoo, muOS, Spruce, etc.) that have no or minimal keyboards and no native file dialogs. Keep the client display- and action-only.

- **Pairing:** Device **displays** a code; user enters it on the dashboard. No “enter code” screen on device.
- **Device name / server URL / custom paths:** Set or changed on the web. Client only reads from storage or API and displays.
- **Adding paths:** Drag-and-drop onto the client window is the only on-device “pick”; no “Browse” or folder picker on device.

**Exception:** Mac (desktop) may support keyboard text input or native file dialogs in future if we add optional desktop-only flows. Other platforms: no typing, no file browser.

## Implications

- Do **not** add `love.keyboard.setTextInput`, on-screen keyboards, or “Enter device name” / “Enter server URL” screens on the client.
- Do **not** add a “Browse for folder” or file picker on the client (except optional Mac-only).
- When adding settings that need text or paths (e.g. device name, server URL, custom paths), implement **edit on dashboard**; client shows read-only or uses stored values only.

## Settings (client)

Only add options that need **no typing and no file browsing**:

| Add | Why OK |
|-----|--------|
| **Unpair** | Single action (with confirmation): clear pairing and return to code screen. |
| **Music: On / Off** (toggle) | Toggle background music on/off. |
| **Sounds: On / Off** (toggle) | Toggle UI sound effects on/off. |
| **Theme: [Name]** (cycle) | Cycle through visual themes (Classic Green, Virtual Boy Red, Game Boy Pocket Blue, Classic Grayscale). Changes colors immediately. |
| Background process: Enabled / Disabled (toggle) | Toggle watcher on/off; runs install or uninstall script accordingly. Left/right or select to toggle. |
| **Go Back** | Already present. |

| Do not add on device | Do on web instead |
|----------------------|--------------------|
| Change device name | Edit device name on dashboard. |
| Server URL | Edit on dashboard or leave default. |
| “Browse for folder” / Add path | Add paths on dashboard or by drag-drop on client. |
