-- src/settings_options.lua
-- Registry of Settings screen options. Add entries here to expand the settings panel.
-- Each option has: id (string), label (string or dynamic via getLabel). Add new rows to
-- OPTIONS, then handle the action in runOptionAtIndex() below. No typing/file browse (see client/UX.md).

local settings = require("src.settings")
local api = require("src.api")
local storage = require("src.storage")

local M = {}

-- Option list: order defines display order. Only options that need no typing/file browse.
-- activatableWithArrows: if true, left/right (or dpleft/dpright) toggle/cycle the option in place.
-- All options respond to space/return/confirm for activation.
local OPTIONS = {
    { id = "music_toggle", activatableWithArrows = true, getLabel = function(s) return (s and s.musicEnabled) and "Music: On" or "Music: Off" end },
    { id = "sounds_toggle", activatableWithArrows = true, getLabel = function(s) return (s and s.soundsEnabled) and "Sounds: On" or "Sounds: Off" end },
    { id = "theme_toggle", activatableWithArrows = true, getLabel = function(s)
        local palette = require("src.ui.palette")
        return "Theme: " .. palette.getCurrentThemeName()
    end },
    { id = "background_toggle", activatableWithArrows = true, getLabel = function(s) return settings.isBackgroundProcessEnabled(s) and "Background process: Enabled" or "Background process: Disabled" end },
    { id = "unpair", label = "Unpair" },
    { id = "back", label = "Go Back" },
}

function M.getOptions(state)
    state = state or {}
    local opts = {}
    for _, o in ipairs(OPTIONS) do
        local label = o.getLabel and o.getLabel(state) or o.label
        opts[#opts + 1] = { id = o.id, label = label }
    end
    return opts
end

function M.getOptionCount()
    return #OPTIONS
end

function M.getOptionAtIndex(index, state)
    local o = OPTIONS[index]
    if not o then return nil end
    state = state or {}
    return {
        id = o.id,
        label = o.getLabel and o.getLabel(state) or o.label,
        activatableWithArrows = o.activatableWithArrows,
    }
end

-- Run the action for the option at the given 1-based index.
-- Returns optional status message string (or nil).
function M.runOptionAtIndex(index, state, configModule)
    local opt = OPTIONS[index]
    if not opt then return nil end
    if opt.id == "music_toggle" then
        state.musicEnabled = not state.musicEnabled
        storage.saveConfig(state)
        if state.bgMusic then
            if state.musicEnabled then state.bgMusic:play() else state.bgMusic:pause() end
        end
        return nil
    elseif opt.id == "sounds_toggle" then
        state.soundsEnabled = not state.soundsEnabled
        storage.saveConfig(state)
        return nil
    elseif opt.id == "theme_toggle" then
        local palette = require("src.ui.palette")
        local nextThemeId = palette.nextTheme()
        palette.setTheme(nextThemeId)
        state.themeId = nextThemeId
        storage.saveConfig(state)
        return nil
    elseif opt.id == "background_toggle" then
        if not settings.runToggleBackgroundProcessAsync(state, configModule) then
            settings.runToggleBackgroundProcessSync(state)
        end
        return nil  -- no tooltip; label updates to show new state
    elseif opt.id == "unpair" then
        state.currentState = configModule.STATE_CONFIRM
        state.confirmMessage = "Are you sure you want to unpair this device?"
        state.confirmYesLabel = "Yes"
        state.confirmNoLabel = "No"
        state.confirmAction = "unpair"
        state.confirmSelectedIndex = 2  -- default to No
        state.confirmBackState = configModule.STATE_SETTINGS
        return nil
    elseif opt.id == "back" then
        state.currentState = configModule.STATE_CONNECTED
        state.settingsStatusMessage = ""
        return nil
    end
    return nil
end

return M
