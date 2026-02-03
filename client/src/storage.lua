-- src/storage.lua
-- Load/save API key, device name, code, server URL, custom paths.
-- Depends: src.config, src.state (caller passes state), src.log (for logMessage).

local config = require("src.config")

local M = {}

local function getLog()
    return require("src.log")
end

function M.loadCode(state)
    local file = io.open(config.CODE_FILE, "r")
    if file then
        local code = file:read("*line")
        file:close()
        if code then
            state.deviceCode = string.upper(code)
            return state.deviceCode
        end
    end
    state.deviceCode = nil
    return nil
end

function M.saveCode(code)
    local file = io.open(config.CODE_FILE, "w")
    if file then
        file:write(code)
        file:close()
    end
end

function M.loadServerUrl(state)
    -- Env override for local testing; otherwise use hardcoded default from config.
    local envUrl = os.getenv("RETROSYNC_SERVER_URL")
    if envUrl and envUrl ~= "" then
        envUrl = envUrl:match("^%s*(.-)%s*$")
        if envUrl and envUrl ~= "" then
            if envUrl:sub(-1) == "/" then
                envUrl = envUrl:sub(1, -2)
            end
            state.serverUrl = envUrl
            return envUrl
        end
    end
    state.serverUrl = config.SERVER_URL
    return config.SERVER_URL
end

function M.loadApiKey(state)
    local file = io.open(config.API_KEY_FILE, "r")
    if file then
        local key = file:read("*line")
        file:close()
        state.apiKey = key
        return key
    end
    state.apiKey = nil
    return nil
end

function M.saveApiKey(key)
    local file = io.open(config.API_KEY_FILE, "w")
    if file then
        file:write(key)
        file:close()
    end
end

function M.loadDeviceName(state)
    local file = io.open(config.DEVICE_NAME_FILE, "r")
    if file then
        local name = file:read("*line")
        file:close()
        state.deviceName = name
        return name
    end
    state.deviceName = nil
    return nil
end

function M.saveDeviceName(name)
    local file = io.open(config.DEVICE_NAME_FILE, "w")
    if file then
        file:write(name)
        file:close()
    end
end

function M.loadAudioPrefs(state)
    state.musicEnabled = false
    state.soundsEnabled = false
    local file = io.open(config.AUDIO_PREFS_FILE, "r")
    if not file then return end
    local line1 = file:read("*l")
    local line2 = file:read("*l")
    file:close()
    if line1 and (line1 == "1" or line1:match("^%s*1%s*$")) then state.musicEnabled = true end
    if line2 and (line2 == "1" or line2:match("^%s*1%s*$")) then state.soundsEnabled = true end
end

function M.saveAudioPrefs(state)
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)
    local file = io.open(config.AUDIO_PREFS_FILE, "w")
    if file then
        file:write(state.musicEnabled and "1" or "0")
        file:write("\n")
        file:write(state.soundsEnabled and "1" or "0")
        file:write("\n")
        file:close()
    end
end

function M.loadTheme(state)
    state.themeId = "classic"  -- default
    local file = io.open(config.THEME_FILE, "r")
    if not file then return end
    local line = file:read("*l")
    file:close()
    if line then
        line = line:match("^%s*(.-)%s*$")
        if line and line ~= "" then
            state.themeId = line
        end
    end
end

function M.saveTheme(themeId)
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)
    local file = io.open(config.THEME_FILE, "w")
    if file then
        file:write(themeId)
        file:write("\n")
        file:close()
    end
end

-- Scan paths: load/save/add are in src.scan_paths (scan_paths.json). Wrapper for add-from-drag so API stays the same.
function M.addTrackablePath(state, path, opts)
    local scan_paths = require("src.scan_paths")
    local ok = scan_paths.addPath(state, path, "custom")
    if ok and (not opts or opts.markDirty ~= false) then
        state.scanPathsDirty = true
    end
    return ok
end

function M.loadNoPathsDismissed(state)
    if not config.NO_PATHS_DISMISSED_FILE then return end
    local file = io.open(config.NO_PATHS_DISMISSED_FILE, "r")
    if not file then return end
    local line = file:read("*l")
    file:close()
    if line and (line == "1" or line:match("^%s*1%s*$")) then
        state.noPathsMessageDismissed = true
    end
end

function M.saveNoPathsDismissed(state)
    if not config.NO_PATHS_DISMISSED_FILE then return end
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)
    local file = io.open(config.NO_PATHS_DISMISSED_FILE, "w")
    if file then
        file:write(state.noPathsMessageDismissed and "1" or "0")
        file:write("\n")
        file:close()
    end
end

return M
