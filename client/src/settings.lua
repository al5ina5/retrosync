-- src/settings.lua
-- Settings helpers: run background process scripts (install/uninstall watcher).
-- Depends: config, log

local config = require("src.config")
local log = require("src.log")

local M = {}

local LOADING_CHANNEL = "retrosync_bg_toggle"

local function runBackgroundScriptSync(scriptPath, appDir, dataDir, actionLabel, isInstall)
    if not scriptPath or scriptPath == "" then
        return false, "Script path not configured"
    end
    local f = io.open(scriptPath, "r")
    if not f then
        return false, "Script not found: " .. scriptPath
    end
    f:close()
    local label = actionLabel or (isInstall and "install" or "uninstall")
    if isInstall then
        log.logMessage("Attempting autostart install")
    else
        log.logMessage("Attempting autostart uninstall")
    end
    local q = function(s) return "'" .. (tostring(s or ""):gsub("'", "'\\''")) .. "'" end
    local cmd = "bash " .. q(scriptPath) .. " " .. q(appDir) .. " " .. q(dataDir) .. " >/dev/null 2>&1"
    log.logMessage("Running background script: " .. tostring(label))
    local ok = os.execute(cmd)
    if isInstall then
        if ok and (ok == true or ok == 0) then
            log.logMessage("Autostart install completed")
        else
            log.logMessage("Autostart install failed")
        end
    else
        if ok and (ok == true or ok == 0) then
            log.logMessage("Autostart uninstall completed")
        else
            log.logMessage("Autostart uninstall failed")
        end
    end
    return (ok == true or ok == 0)
end

-- Thread code: receives scriptPath, appDir, dataDir; runs script with those args; pushes result to channel.
local THREAD_CODE = [[
    local scriptPath = select(1, ...)
    local appDir = select(2, ...)
    local dataDir = select(3, ...)
    local channel = love.thread.getChannel("]] .. LOADING_CHANNEL .. [[")
    if not scriptPath or scriptPath == "" then
        channel:push("error")
        return
    end
    local q = function(s) return "'" .. (tostring(s or ""):gsub("'", "'\\''")) .. "'" end
    local cmd = "bash " .. q(scriptPath) .. " " .. q(appDir) .. " " .. q(dataDir) .. " >/dev/null 2>&1"
    local ok = os.execute(cmd)
    channel:push((ok == true or ok == 0) and "done" or "error")
]]

-- Returns true if background process (watcher + autostart) is currently enabled.
-- Uses single state.autostart and config.AUTOSTART_PLATFORM ("macos" | "spruceos" | "muos").
function M.isBackgroundProcessEnabled(state)
    if not state or not config.AUTOSTART_PLATFORM then return false end
    return state.autostart == config.AUTOSTART_PLATFORM
end

-- Start toggle in background thread. Caller must set state to LOADING and poll
-- state.loadingDoneChannel. Returns true if thread started, false to fall back to sync.
function M.runToggleBackgroundProcessAsync(state, configModule)
    local scriptPath
    if M.isBackgroundProcessEnabled(state) then
        scriptPath = config.UNINSTALL_BG_SCRIPT
    else
        scriptPath = config.INSTALL_BG_SCRIPT
    end
    if not scriptPath or scriptPath == "" then
        return false
    end
    local f = io.open(scriptPath, "r")
    if not f then
        return false
    end
    f:close()

    local ok, thread = pcall(love.thread.newThread, THREAD_CODE)
    if not ok or not thread then
        log.logMessage("love.thread.newThread failed, falling back to sync")
        return false
    end

    local chan = love.thread.getChannel(LOADING_CHANNEL)
    chan:clear()
    local isInstall = not M.isBackgroundProcessEnabled(state)
    if isInstall then
        log.logMessage("Attempting autostart install")
    else
        log.logMessage("Attempting autostart uninstall")
    end
    -- Pass scriptPath, appDir, dataDir so scripts can write autostart sidecar into config dir
    thread:start(scriptPath, configModule.APP_DIR, configModule.DATA_DIR)

    state.loadingMessage = "Loading"
    state.loadingBackState = configModule.STATE_SETTINGS
    state.loadingDoneChannel = chan
    state.loadingWasInstall = isInstall
    state.currentState = configModule.STATE_LOADING
    log.logMessage("Background toggle started (async)")
    return true
end

-- Synchronous fallback when threads unavailable (e.g. some embedded platforms).
function M.runToggleBackgroundProcessSync(state)
    local enabled = M.isBackgroundProcessEnabled(state)
    local scriptPath = enabled and config.UNINSTALL_BG_SCRIPT or config.INSTALL_BG_SCRIPT
    if not scriptPath or scriptPath == "" then return end
    local isInstall = not enabled
    local ok = runBackgroundScriptSync(scriptPath, config.APP_DIR, config.DATA_DIR, enabled and "Disable" or "Enable", isInstall)
    if ok and config.AUTOSTART_PLATFORM then
        local storage = require("src.storage")
        state.autostart = isInstall and config.AUTOSTART_PLATFORM or false
        storage.saveConfig(state)
    end
end

return M
