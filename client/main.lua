-- main.lua - RetroSync Lua Client for LÖVE 11.x
-- Shows pairing code entry, handles connection, uploads saves

-- Allow require("src.xxx") to resolve to client/src/xxx.lua
local base = love and love.filesystem and love.filesystem.getSource() or "."
if not base or base == "" then base = "." end
package.path = package.path .. ";" .. base .. "/?.lua"

local json = require("lib.dkjson")
local config = require("src.config")
local log = require("src.log")
local state = require("src.state")
local storage = require("src.storage")
local http = require("src.http")
local api = require("src.api")
local saves_list = require("src.saves_list")
local fs = require("src.fs")
local device_history = require("src.device_history")
local download = require("src.download")
local upload = require("src.upload")
local settings = require("src.settings")
local assets = require("src.assets")
local ui = require("src.ui")
local input = require("src.input")

-- Optional: drag-over detection for "RELEASE TO ADD PATH" hint (uses FFI/SDL; may fail on some platforms)
local dropping
do
    local ok, err = pcall(function()
        dropping = require("lib.isdropping")
    end)
    if not ok or not dropping then
        dropping = nil
        if log and log.logMessage then log.logMessage("isdropping not loaded: " .. tostring(err or "nil")) end
    end
end

function love.load()
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.setDefaultFilter("nearest", "nearest")

    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
        os.execute("mkdir -p '" .. config.LOGS_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
        os.execute("mkdir -p '" .. config.WATCHER_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
    end)
    log.migrateLegacyLog()
    storage.loadConfig(state)
    storage.loadServerUrl(state)
    local palette = require("src.ui.palette")
    palette.setTheme(state.themeId or "classic")
    assets.load(state)
    device_history.load(state)
    local scan_paths = require("src.scan_paths")
    scan_paths.load(state)
    
    log.logMessage("=== RetroSync App Started ===")
    log.logMessage("App directory: " .. config.APP_DIR)
    log.logMessage("Data directory: " .. config.DATA_DIR)
    log.logMessage("Server URL: " .. (state.serverUrl or config.SERVER_URL or ""))
    
    if state.apiKey then
        state.currentState = config.STATE_CONNECTED
        state.isPaired = true
        state.homeIntroTimer = 0
    else
        state.currentState = config.STATE_SHOWING_CODE
        state.isPaired = false
        state.codeIntroTimer = 0
        if not state.deviceCode then
            api.getCodeFromServer()
        end
    end

    -- On macOS: run autostart installer so LaunchAgent runs watcher at login (like muOS/Spruce).
    -- Skip only if config says installed and plist already has DATA_DIR (fast path). Otherwise run install so watcher uses LÖVE data dir.
    if love.system and love.system.getOS and love.system.getOS() == "OS X" then
        config.INSTALL_BG_SCRIPT = config.APP_DIR .. "/autostart/macos-install.sh"
        config.UNINSTALL_BG_SCRIPT = config.APP_DIR .. "/autostart/macos-uninstall.sh"
        config.AUTOSTART_PLATFORM = "macos"
        local plistPath = (os.getenv("HOME") or "") .. "/Library/LaunchAgents/com.retrosync.watcher.plist"
        local plistStale = true
        if state.autostart == "macos" and plistPath ~= "" then
            local pf = io.open(plistPath, "r")
            if pf then
                local content = pf:read("*a")
                pf:close()
                -- New plist passes DATA_DIR as 4th ProgramArgument; plist contains the data dir path
                if content and content:find(config.DATA_DIR, 1, true) then
                    plistStale = false
                end
            end
        else
            plistStale = (state.autostart ~= "macos")
        end
        if plistStale then
            -- Run install (updates plist with DATA_DIR and restarts watcher so files go to data/watcher/)
            local installScript = config.APP_DIR .. "/autostart/macos-install.sh"
            local f = io.open(installScript, "r")
            if f then
                f:close()
                local q = function(s) return "'" .. (tostring(s or ""):gsub("'", "'\\''")) .. "'" end
                local cmd = "bash " .. q(installScript) .. " " .. q(config.APP_DIR) .. " " .. q(config.DATA_DIR) .. " >/dev/null 2>&1"
                log.logMessage("macOS: attempting to start watcher (via launchd autostart install)")
                log.logMessage("macOS: attempting autostart install")
                local ok = os.execute(cmd)
                if ok and (ok == true or ok == 0) then
                    log.logMessage("macOS: watcher started successfully (launchd loaded)")
                    log.logMessage("macOS: autostart install completed")
                else
                    log.logMessage("macOS: watcher failed to start (launchd load failed)")
                    log.logMessage("macOS: autostart install failed")
                end
            else
                log.logMessage("macOS: autostart/macos-install.sh not found at " .. installScript)
            end
        end
    end

    -- On Linux (Miyoo Flip, etc.): detect muOS or Spruce and set autostart script paths
    if love.system and love.system.getOS and love.system.getOS() == "Linux" then
        local appDir = config.APP_DIR
        local dataDir = config.DATA_DIR
        local spruceOk = os.execute("test -f /mnt/SDCARD/spruce/scripts/networkservices.sh") == 0
        if spruceOk then
            config.INSTALL_BG_SCRIPT = appDir .. "/autostart/spruce-install.sh"
            config.UNINSTALL_BG_SCRIPT = appDir .. "/autostart/spruce-uninstall.sh"
            config.AUTOSTART_PLATFORM = "spruceos"
            log.logMessage("Linux: using Spruce autostart (Miyoo Flip, etc.)")
        else
            local muosOk = (os.execute("test -d /mnt/mmc/MUOS/init") == 0) or (os.execute("test -d /mnt/sdcard/MUOS/init") == 0)
            if muosOk then
                config.INSTALL_BG_SCRIPT = appDir .. "/autostart/muos-install.sh"
                config.UNINSTALL_BG_SCRIPT = appDir .. "/autostart/muos-uninstall.sh"
                config.AUTOSTART_PLATFORM = "muos"
                log.logMessage("Linux: using muOS autostart")
            end
        end
    end

    -- Drag-over hint: "RELEASE TO ADD PATH" while cursor (held from outside) is over window
    if dropping then
        love.isdropping = function(_, _) state.dragOverWindow = true end
        love.stoppeddropping = function() state.dragOverWindow = false end
    end
end

function love.quit()
    if state.weStartedWatcher then
        local pidFile = config.WATCHER_DIR .. "/watcher.pid"
        local f = io.open(pidFile, "r")
        if f then
            local pid = f:read("*l")
            f:close()
            if pid and pid ~= "" then
                log.logMessage("macOS: stopping watcher (pid=" .. pid .. ")")
                os.execute("kill " .. pid .. " 2>/dev/null")
            end
        end
    end
    log.logMessage("=== RetroSync App Closing ===")
end

-- Drag-and-drop: directory dropped onto window (Mac/Windows)
function love.directorydropped(path)
    state.dragOverWindow = false
    log.logMessage("directorydropped: " .. tostring(path))
    if type(path) ~= "string" or path == "" then return end
    storage.addTrackablePath(state, path)
    state.pathAddedMessage = ui.normalizePathForCustom(path) or path
    state.pathAddedAt = love.timer.getTime()
end

-- Drag-and-drop: file dropped onto window; we add its parent directory (Mac/Windows)
function love.filedropped(file)
    state.dragOverWindow = false
    local path = nil
    if type(file) == "string" then
        path = file
    elseif type(file) == "table" or type(file) == "userdata" then
        local ok, result = pcall(function()
            if file.getFilename then
                return file:getFilename()
            end
            return nil
        end)
        if ok and result and type(result) == "string" then
            path = result
        end
    end
    if not path or path == "" then
        log.logMessage("filedropped: could not get path from dropped file")
        if type(file) == "userdata" and file.release then
            pcall(function() file:release() end)
        end
        return
    end
    local dir = path:match("(.*)/") or path:match("(.*)\\[^\\]*$") or path
    storage.addTrackablePath(state, dir)
    state.pathAddedMessage = ui.normalizePathForCustom(dir) or dir
    state.pathAddedAt = love.timer.getTime()
    if type(file) == "userdata" and file.release then
        pcall(function() file:release() end)
    end
end

function love.update(dt)
    if dropping then dropping.eventUpdate() end
    state.pollTimer = state.pollTimer + dt
    state.pollIndicator = state.pollIndicator + dt

    -- Advance home intro animation while on CONNECTED screen
    if state.currentState == config.STATE_CONNECTED and state.homeIntroTimer < config.homeIntroDuration then
        state.homeIntroTimer = math.min(state.homeIntroTimer + dt, config.homeIntroDuration)
    end
    
    -- Advance code intro animation while on SHOWING_CODE screen
    if state.currentState == config.STATE_SHOWING_CODE and state.codeIntroTimer < config.codeIntroDuration then
        state.codeIntroTimer = math.min(state.codeIntroTimer + dt, config.codeIntroDuration)
    end
    
    -- Clear the "just started" flag after a short delay to allow cancellation
    if state.uploadJustStarted then
        state.uploadStartTimer = state.uploadStartTimer + dt
        if state.uploadStartTimer >= 0.5 then
            state.uploadJustStarted = false
            state.uploadStartTimer = 0
        end
    end
    
    -- Phase 1: Show SYNCING screen immediately (no work this frame)
    if state.uploadPending then
        state.uploadPending = false
        state.uploadDiscoverPending = true
        return
    end

    -- Phase 2: Discover files (one frame); SYNCING already visible
    if state.uploadDiscoverPending then
        state.uploadDiscoverPending = false
        upload.doUploadDiscover()
        return
    end

    -- Phase 3: Upload one file per frame so UI updates in real time
    if state.uploadInProgress then
        upload.doUploadOneFile()
        return
    end

    -- Download: Phase 1 (show screen immediately)
    if state.downloadPending then
        state.downloadPending = false
        download.doDownloadDiscover()
        return
    end

    -- Download: Phase 2 (one file per frame)
    if state.downloadInProgress then
        download.doDownloadOneFile()
        return
    end
    
    -- Files list: Defer API call to next frame so screen renders first
    if state.filesListPending then
        state.filesListPending = false
        saves_list.fetchSavesList(fs.getFileMtimeSeconds)
        return
    end
    
    -- If we're showing code but don't have one yet, try to get it
    if state.currentState == config.STATE_SHOWING_CODE and not state.deviceCode and state.pollTimer >= 1 then
        state.pollTimer = 0
        log.logMessage("No device code yet, attempting to fetch...")
        api.getCodeFromServer()
    end
    
    -- Poll server to check if device has been paired (when showing code)
    if state.currentState == config.STATE_SHOWING_CODE and state.deviceCode and state.pollTimer >= 2 then
        state.pollTimer = 0
        -- Reset poll indicator to show activity
        state.pollIndicator = 0
        api.checkPairingStatus()
    end
    
    -- Poll server heartbeat every 5 seconds if connected
    if state.currentState == config.STATE_CONNECTED and state.pollTimer >= 5 then
        state.pollTimer = 0
        api.sendHeartbeat()
    end

    -- Loading overlay: poll for background toggle thread completion
    if state.currentState == config.STATE_LOADING and state.loadingDoneChannel then
        local result = state.loadingDoneChannel:pop()
        if result then
            local wasInstall = state.loadingWasInstall
            state.loadingDoneChannel = nil
            state.loadingWasInstall = nil
            state.currentState = state.loadingBackState or config.STATE_SETTINGS
            if wasInstall then
                if result == "done" then
                    log.logMessage("Autostart install completed")
                    if config.AUTOSTART_PLATFORM then state.autostart = config.AUTOSTART_PLATFORM; storage.saveConfig(state) end
                else
                    log.logMessage("Autostart install failed")
                end
            else
                if result == "done" then
                    log.logMessage("Autostart uninstall completed")
                    state.autostart = false
                    storage.saveConfig(state)
                else
                    log.logMessage("Autostart uninstall failed")
                end
            end
        end
    end
end

function love.draw()
    ui.draw(state, config)
end

function love.keypressed(key)
    input.handleKeypressed(state, config, key)
end


function love.gamepadpressed(joystick, button)
    input.handleGamepadpressed(state, config, joystick, button)
end

function love.mousepressed(x, y, button, istouch, presses)
    input.handleMousepressed(state, config, x, y, button)
end


-- Pairing/API: src.api; Saves list: src/saves_list (saves_list.fetchSavesList, saves_list.showFilesList)

-- Display helpers: src/ui.lua (ui.formatFileSize, ui.truncateToWidth, ui.formatHistoryTime)

-- Upload/download/fs logic moved to src/upload.lua, src/download.lua, src/fs.lua

-- Config: storage.loadConfig(state), storage.saveConfig(state). Scan paths: src/scan_paths.lua; add via storage.addTrackablePath (drag-drop).

-- Device history: load/add in src/device_history.lua
-- formatHistoryTime: src/ui.lua (ui.formatHistoryTime)

-- Background process: src/settings.lua (settings.runToggleBackgroundProcess, settings.isBackgroundProcessEnabled)

-- JSON decoding is now handled by dkjson library
-- Logging is in src.log (log.logMessage, log.migrateLegacyLog); logs go to data/logs/YYYY-MM-DD.log
