-- src/storage.lua
-- Load/save config (config.json). Migration from legacy marker files on first run.
-- Depends: src.config, src.state (caller passes state), src.log (for logMessage).

local config = require("src.config")
local json = require("lib.dkjson")

local M = {}

local function getLog()
    return require("src.log")
end

local dataDir = function()
    return config.DATA_DIR
end

-- Build config table from legacy marker files (for migration).
-- Single autostart field: false | "macos" | "spruceos" | "muos"
local function readLegacyConfig()
    local out = {
        apiKey = nil,
        deviceName = nil,
        code = nil,
        serverUrl = config.SERVER_URL,
        themeId = "classic",
        musicEnabled = false,
        soundsEnabled = false,
        noPathsMessageDismissed = false,
        autostart = false,
    }
    local dir = dataDir()
    local function readLine(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local line = f:read("*l")
        f:close()
        if line then line = line:match("^%s*(.-)%s*$") end
        return line and line ~= "" and line or nil
    end
    out.apiKey = readLine(dir .. "/api_key")
    out.deviceName = readLine(dir .. "/device_name")
    out.code = readLine(dir .. "/code")
    if out.code then out.code = string.upper(out.code) end
    out.themeId = readLine(dir .. "/theme") or "classic"
    local prefs = io.open(dir .. "/audio_prefs", "r")
    if prefs then
        local l1, l2 = prefs:read("*l"), prefs:read("*l")
        prefs:close()
        if l1 and (l1 == "1" or l1:match("^%s*1%s*$")) then out.musicEnabled = true end
        if l2 and (l2 == "1" or l2:match("^%s*1%s*$")) then out.soundsEnabled = true end
    end
    local noPath = readLine(dir .. "/no_paths_dismissed")
    if noPath and (noPath == "1" or noPath:match("^%s*1%s*$")) then out.noPathsMessageDismissed = true end
    -- Legacy marker files (scripts used to touch these)
    local function markerExists(name)
        local f = io.open(dir .. "/" .. name, "r")
        if f then f:close(); return true end
        return false
    end
    if markerExists("macos_autostart_installed") then out.autostart = "macos" end
    -- One-time migration from old autostart_macos.txt sidecar (no longer used; scripts write config.json)
    do
        local f = io.open(dir .. "/autostart_macos.txt", "r")
        if f then
            local line = f:read("*l")
            f:close()
            pcall(function() os.remove(dir .. "/autostart_macos.txt") end)
            if line and line:match("^%s*1%s*$") then out.autostart = "macos" end
            if line and line:match("^%s*0%s*$") then out.autostart = false end
        end
    end
    if markerExists("spruce_autostart_installed") then out.autostart = "spruceos" end
    if markerExists("muos_autostart_installed") then out.autostart = "muos" end
    return out
end

-- Load config from config.json, or migrate from legacy files and save config.json.
function M.loadConfig(state)
    state.apiKey = nil
    state.deviceName = nil
    state.deviceCode = nil
    state.themeId = "classic"
    state.musicEnabled = false
    state.soundsEnabled = false
    state.noPathsMessageDismissed = false
    state.autostart = false

    local path = config.CONFIG_FILE
    local file = io.open(path, "r")
    if file then
        local raw = file:read("*a")
        file:close()
        if raw and raw ~= "" then
            local ok, data = pcall(json.decode, raw)
            if ok and data and type(data) == "table" then
                state.apiKey = data.apiKey
                state.deviceName = data.deviceName
                state.deviceCode = (data.code and data.code ~= "") and string.upper(data.code) or nil
                state.serverUrl = (data.serverUrl and data.serverUrl ~= "") and data.serverUrl or config.SERVER_URL
                state.themeId = (data.themeId and data.themeId ~= "") and data.themeId or "classic"
                state.musicEnabled = data.musicEnabled == true
                state.soundsEnabled = data.soundsEnabled == true
                state.noPathsMessageDismissed = data.noPathsMessageDismissed == true
                -- Single autostart: false | "macos" | "spruceos" | "muos"; migrate old boolean keys
                if data.autostart and type(data.autostart) == "string" and data.autostart ~= "" then
                    state.autostart = data.autostart
                elseif data.macosAutostartInstalled == true then
                    state.autostart = "macos"
                elseif data.spruceAutostartInstalled == true then
                    state.autostart = "spruceos"
                elseif data.muosAutostartInstalled == true then
                    state.autostart = "muos"
                end
                if M.applyAutostartSidecars(state) then M.saveConfig(state) end
                return
            end
        end
    end

    -- Migrate from legacy files
    local legacy = readLegacyConfig()
    state.apiKey = legacy.apiKey
    state.deviceName = legacy.deviceName
    state.deviceCode = legacy.code
    state.serverUrl = legacy.serverUrl
    state.themeId = legacy.themeId
    state.musicEnabled = legacy.musicEnabled
    state.soundsEnabled = legacy.soundsEnabled
    state.noPathsMessageDismissed = legacy.noPathsMessageDismissed
    state.autostart = legacy.autostart
    M.applyAutostartSidecars(state)
    getLog().logMessage("storage: migrated config from legacy files, writing config.json")
    M.saveConfig(state)
end

-- Apply sidecar files written by install/uninstall scripts (spruce/muos only). macOS uses config.json only (scripts update via jq). Scripts write "1" or "0" to data/autostart_<platform>.txt; we merge into state.autostart and delete the file. Returns true if any sidecar was applied.
function M.applyAutostartSidecars(state)
    local dir = dataDir()
    local changed = false
    local function apply(name, platformValue)
        local f = io.open(dir .. "/autostart_" .. name .. ".txt", "r")
        if not f then return end
        local line = f:read("*l")
        f:close()
        pcall(function() os.remove(dir .. "/autostart_" .. name .. ".txt") end)
        if line and line:match("^%s*1%s*$") then state.autostart = platformValue; changed = true
        elseif line and line:match("^%s*0%s*$") and state.autostart == platformValue then state.autostart = false; changed = true
        end
    end
    apply("spruce", "spruceos")
    apply("muos", "muos")
    return changed
end

-- Write full config to config.json.
function M.saveConfig(state)
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
    end)
    local data = {
        apiKey = state.apiKey,
        deviceName = state.deviceName,
        code = state.deviceCode,
        serverUrl = state.serverUrl or config.SERVER_URL,
        themeId = state.themeId or "classic",
        musicEnabled = state.musicEnabled == true,
        soundsEnabled = state.soundsEnabled == true,
        noPathsMessageDismissed = state.noPathsMessageDismissed == true,
        autostart = state.autostart,
    }
    local path = config.CONFIG_FILE
    local file = io.open(path, "w")
    if file then
        file:write(json.encode(data))
        file:close()
    end
end

function M.loadServerUrl(state)
    local envUrl = os.getenv("RETROSYNC_SERVER_URL")
    if envUrl and envUrl ~= "" then
        envUrl = envUrl:match("^%s*(.-)%s*$")
        if envUrl and envUrl ~= "" then
            if envUrl:sub(-1) == "/" then envUrl = envUrl:sub(1, -2) end
            state.serverUrl = envUrl
            return envUrl
        end
    end
    if not state.serverUrl or state.serverUrl == "" then
        state.serverUrl = config.SERVER_URL
    end
    return state.serverUrl
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

return M
