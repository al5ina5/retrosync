# Theme System

The Lua client now supports multiple Game Boy-style color themes that can be toggled from the Settings screen.

## Available Themes

1. **Classic Green** (default)
   - The original Game Boy (DMG) green palette
   - Colors: `#0f380f`, `#306230`, `#8bac0f`, `#9bbc0f`

2. **Virtual Boy Red**
   - Red monochrome inspired by the Virtual Boy console
   - Deep red tones with high contrast

3. **Game Boy Pocket Blue**
   - Blue-tinted palette reminiscent of Game Boy Pocket
   - Cool blue tones with good readability

4. **Classic Grayscale**
   - Black and white Game Boy Pocket style
   - Pure monochrome for maximum contrast

## How to Use

1. Launch the RetroSync client
2. Navigate to **Settings** from the main menu
3. Select **Theme: [Current Theme Name]** 
4. Press the action button to cycle through themes
5. The theme changes immediately and persists across app restarts

## Implementation Details

### Files Modified

- **`src/ui/palette.lua`** - Theme definitions and switching logic
- **`src/storage.lua`** - Theme persistence (load/save)
- **`src/config.lua`** - Theme file path configuration
- **`src/settings_options.lua`** - Theme toggle option in settings menu
- **`src/state.lua`** - Theme state tracking
- **`main.lua`** - Theme initialization on app startup

### Theme Storage

The current theme preference is saved to `data/theme` as a plain text file containing the theme ID (e.g., "classic", "red", "blue", "grayscale").

### Adding New Themes

To add a new theme:

1. Edit `client/src/ui/palette.lua`
2. Add a new entry to the `THEMES` table with 4 color shades:
   ```lua
   mytheme = {
       name = "My Theme Name",
       darkest = { r/255, g/255, b/255 },
       dark = { r/255, g/255, b/255 },
       light = { r/255, g/255, b/255 },
       lightest = { r/255, g/255, b/255 },
   }
   ```
3. Add the theme ID to `M.THEME_ORDER` array to include it in the cycle

All UI screens automatically use the active theme through the design system (`design.p.*` color references).

## Technical Notes

- Theme changes apply immediately without requiring an app restart
- All color references use the centralized palette module through the design system
- The theme system is fully compatible with all platforms (macOS, Linux, muOS, Spruce, etc.)
- No changes to the web dashboard are needed - this is a client-only feature
