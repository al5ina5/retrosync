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
    local file = io.open(config.SERVER_URL_FILE, "r")
    if file then
        local line = file:read("*line")
        file:close()
        if line then
            line = line:match("^%s*(.-)%s*$")
            if line and line ~= "" then
                if line:sub(-1) == "/" then
                    line = line:sub(1, -2)
                end
                state.serverUrl = line
                return line
            end
        end
    end
    return nil
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

function M.loadCustomPaths(state)
    state.customTrackablePaths = {}
    local file = io.open(config.CUSTOM_PATHS_FILE, "r")
    if not file then
        getLog().logMessage("loadCustomPaths: no file at " .. config.CUSTOM_PATHS_FILE .. " (ok on first run)")
        return
    end
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line and line ~= "" then
            if line:sub(-1) == "/" then
                line = line:sub(1, -2)
            end
            table.insert(state.customTrackablePaths, line)
        end
    end
    file:close()
    getLog().logMessage("loadCustomPaths: loaded " .. #state.customTrackablePaths .. " paths from " .. config.CUSTOM_PATHS_FILE)
end

-- Normalize path for dedup: strip trailing slash, trim
local function normalizePath(path)
    if not path or path == "" then return nil end
    path = path:match("^%s*(.-)%s*$")
    if path == "" then return nil end
    if path:sub(-1) == "/" then
        path = path:sub(1, -2)
    end
    return path
end

function M.addTrackablePath(state, path)
    local norm = normalizePath(path)
    if not norm then return false end
    for _, p in ipairs(state.customTrackablePaths) do
        if p == norm then return false end
    end
    table.insert(state.customTrackablePaths, norm)
    M.saveCustomPaths(state)
    getLog().logMessage("Custom path added: " .. norm)
    return true
end

function M.saveCustomPaths(state)
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
        if love.system and love.system.getOS then
            local osname = love.system.getOS()
            if osname == "Windows" then
                os.execute('mkdir "' .. config.DATA_DIR:gsub("/", "\\") .. '" 2>nul')
            end
        end
    end)
    local file = io.open(config.CUSTOM_PATHS_FILE, "w")
    if file then
        for _, p in ipairs(state.customTrackablePaths) do
            file:write(p .. "\n")
        end
        file:close()
        getLog().logMessage("saveCustomPaths: saved " .. #state.customTrackablePaths .. " paths to " .. config.CUSTOM_PATHS_FILE)
    else
        getLog().logMessage("saveCustomPaths: failed to open " .. config.CUSTOM_PATHS_FILE .. " for writing")
    end
end

return M
