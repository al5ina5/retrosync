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
-- Tries DATA_DIR first, then APP_DIR/data (old installs used data/ next to game).
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
    local legacyDir = config.APP_DIR .. "/data"
    local function readLine(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local line = f:read("*l")
        f:close()
        if line then line = line:match("^%s*(.-)%s*$") end
        return line and line ~= "" and line or nil
    end
    local function readFromEither(subpath)
        return readLine(dir .. subpath) or readLine(legacyDir .. subpath)
    end
    out.apiKey = readFromEither("/api_key")
    out.deviceName = readFromEither("/device_name")
    out.code = readFromEither("/code")
    do
        local url = readFromEither("/server_url")
        if url and url ~= "" then out.serverUrl = url end
    end
    if out.code then out.code = string.upper(out.code) end
    out.themeId = readFromEither("/theme") or "classic"
    local prefs = io.open(dir .. "/audio_prefs", "r") or io.open(legacyDir .. "/audio_prefs", "r")
    if prefs then
        local l1, l2 = prefs:read("*l"), prefs:read("*l")
        prefs:close()
        if l1 and (l1 == "1" or l1:match("^%s*1%s*$")) then out.musicEnabled = true end
        if l2 and (l2 == "1" or l2:match("^%s*1%s*$")) then out.soundsEnabled = true end
    end
    local noPath = readFromEither("/no_paths_dismissed")
    if noPath and (noPath == "1" or noPath:match("^%s*1%s*$")) then out.noPathsMessageDismissed = true end
    -- Legacy marker files (scripts used to touch these)
    local function markerExists(name)
        local f = io.open(dir .. "/" .. name, "r") or io.open(legacyDir .. "/" .. name, "r")
        if f then f:close(); return true end
        return false
    end
    if markerExists("macos_autostart_installed") then out.autostart = "macos" end
    -- One-time migration from old autostart_macos.txt sidecar (no longer used; scripts write config.json)
    do
        local f = io.open(dir .. "/autostart_macos.txt", "r") or io.open(legacyDir .. "/autostart_macos.txt", "r")
        if f then
            local line = f:read("*l")
            f:close()
            pcall(function() os.remove(dir .. "/autostart_macos.txt") end)
            pcall(function() os.remove(legacyDir .. "/autostart_macos.txt") end)
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
    -- One-time migration: old installs used APP_DIR/data; LÖVE uses getSaveDirectory() (e.g. saves/love/retrosync).
    local legacyDataPath = config.APP_DIR .. "/data/config.json"
    local legacyFile = io.open(legacyDataPath, "r")
    if legacyFile then
        local content = legacyFile:read("*a")
        legacyFile:close()
        if content and content ~= "" then
            pcall(function()
                os.execute("mkdir -p '" .. config.DATA_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
                local out = io.open(path, "w")
                if out then out:write(content); out:close() end
            end)
            getLog().logMessage("storage: migrated config.json from legacy data/ to LÖVE data dir")
        end
    end

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
                -- All config in one file: deviceHistory and scanPaths
                state.deviceHistory = (type(data.deviceHistory) == "table") and data.deviceHistory or {}
                state.scanPathEntries = (type(data.scanPaths) == "table") and data.scanPaths or {}
                -- One-time migration from old separate files if config had no deviceHistory/scanPaths
                local needSave = false
                if #state.deviceHistory == 0 then
                    local histPath = config.DATA_DIR .. "/device_history.json"
                    local f = io.open(histPath, "r")
                    if f then
                        local content = f:read("*a")
                        f:close()
                        if content and content ~= "" then
                            local ok, arr = pcall(json.decode, content)
                            if ok and type(arr) == "table" then state.deviceHistory = arr; needSave = true end
                        end
                        pcall(function() os.remove(histPath) end)
                    end
                end
                if #state.scanPathEntries == 0 then
                    local scanPath = config.DATA_DIR .. "/scan_paths.json"
                    local f = io.open(scanPath, "r")
                    if f then
                        local content = f:read("*a")
                        f:close()
                        if content and content ~= "" then
                            local ok, d = pcall(json.decode, content)
                            if ok and d and type(d.paths) == "table" then state.scanPathEntries = d.paths; needSave = true end
                        end
                        pcall(function() os.remove(scanPath) end)
                    end
                    local customPath = config.DATA_DIR .. "/custom_paths.txt"
                    local cf = io.open(customPath, "r")
                    if cf then
                        for line in cf:lines() do
                            line = line and line:match("^%s*(.-)%s*$") or ""
                            if line ~= "" then table.insert(state.scanPathEntries, { path = line, kind = "custom" }); needSave = true end
                        end
                        cf:close()
                        pcall(function() os.remove(customPath) end)
                    end
                end
                if M.applyAutostartSidecars(state) then needSave = true end
                if needSave then M.saveConfig(state) end
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
    state.deviceHistory = {}
    state.scanPathEntries = {}
    -- One-time migration from old separate files into config.json
    local historyPath = config.DATA_DIR .. "/device_history.json"
    local histFile = io.open(historyPath, "r")
    if histFile then
        local content = histFile:read("*a")
        histFile:close()
        if content and content ~= "" then
            local ok, arr = pcall(json.decode, content)
            if ok and type(arr) == "table" then state.deviceHistory = arr end
        end
        pcall(function() os.remove(historyPath) end)
    end
    local scanPath = config.DATA_DIR .. "/scan_paths.json"
    local scanFile = io.open(scanPath, "r")
    if scanFile then
        local content = scanFile:read("*a")
        scanFile:close()
        if content and content ~= "" then
            local ok, data = pcall(json.decode, content)
            if ok and data and type(data.paths) == "table" then state.scanPathEntries = data.paths end
        end
        pcall(function() os.remove(scanPath) end)
    end
    local customPath = config.DATA_DIR .. "/custom_paths.txt"
    local customFile = io.open(customPath, "r")
    if customFile then
        for line in customFile:lines() do
            line = line and line:match("^%s*(.-)%s*$") or ""
            if line ~= "" then
                table.insert(state.scanPathEntries, { path = line, kind = "custom" })
            end
        end
        customFile:close()
        pcall(function() os.remove(customPath) end)
    end
    M.applyAutostartSidecars(state)
    getLog().logMessage("storage: migrated config from legacy files, writing config.json")
    M.saveConfig(state)
end

-- Apply sidecar files written by install/uninstall scripts (spruce/muos only). macOS uses config.json only (scripts update via jq). Scripts write "1" or "0" to data/autostart_<platform>.txt; we merge into state.autostart and delete the file. Also checks legacy APP_DIR/data. Returns true if any sidecar was applied.
function M.applyAutostartSidecars(state)
    local dir = dataDir()
    local legacyDir = config.APP_DIR .. "/data"
    local changed = false
    local function apply(name, platformValue)
        local path = dir .. "/autostart_" .. name .. ".txt"
        local f = io.open(path, "r")
        if not f then
            path = legacyDir .. "/autostart_" .. name .. ".txt"
            f = io.open(path, "r")
        end
        if not f then return end
        local line = f:read("*l")
        f:close()
        pcall(function() os.remove(dir .. "/autostart_" .. name .. ".txt") end)
        pcall(function() os.remove(legacyDir .. "/autostart_" .. name .. ".txt") end)
        if line and line:match("^%s*1%s*$") then state.autostart = platformValue; changed = true
        elseif line and line:match("^%s*0%s*$") and state.autostart == platformValue then state.autostart = false; changed = true
        end
    end
    apply("spruce", "spruceos")
    apply("muos", "muos")
    return changed
end

-- Write full config to config.json (all settings, deviceHistory, scanPaths).
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
        deviceHistory = state.deviceHistory or {},
        scanPaths = state.scanPathEntries or {},
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
