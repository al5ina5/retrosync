-- src/settings.lua
-- Settings helpers: run background process scripts (install/uninstall watcher).
-- Depends: config, log

local config = require("src.config")
local log = require("src.log")

local M = {}

local LOADING_CHANNEL = "retrosync_bg_toggle"

local function runBackgroundScriptSync(scriptPath, actionLabel)
    if not scriptPath or scriptPath == "" then
        return false, "Script path not configured"
    end
    local f = io.open(scriptPath, "r")
    if not f then
        return false, "Script not found: " .. scriptPath
    end
    f:close()
    local quoted = "'" .. tostring(scriptPath):gsub("'", "'\\''") .. "'"
    local cmd = "bash " .. quoted .. " >/dev/null 2>&1"
    log.logMessage("Running background script: " .. cmd .. " (" .. tostring(actionLabel) .. ")")
    local ok = os.execute(cmd)
    return (ok == true or ok == 0)
end

-- Thread code: receives scriptPath, runs it, pushes result to channel.
-- Runs in love.thread so main loop stays responsive.
local THREAD_CODE = [[
    local scriptPath = ...
    local channel = love.thread.getChannel("]] .. LOADING_CHANNEL .. [[")
    if not scriptPath or scriptPath == "" then
        channel:push("error")
        return
    end
    local quoted = "'" .. tostring(scriptPath):gsub("'", "'\\''") .. "'"
    local cmd = "bash " .. quoted .. " >/dev/null 2>&1"
    local ok = os.execute(cmd)
    channel:push((ok == true or ok == 0) and "done" or "error")
]]

-- Returns true if background process (watcher + autostart) is currently enabled.
-- Uses platform-specific marker file set by main.lua (config.BG_MARKER_FILE).
function M.isBackgroundProcessEnabled()
    local marker = config.BG_MARKER_FILE
    if not marker or marker == "" then
        return false
    end
    local f = io.open(marker, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Start toggle in background thread. Caller must set state to LOADING and poll
-- state.loadingDoneChannel. Returns true if thread started, false to fall back to sync.
function M.runToggleBackgroundProcessAsync(state, configModule)
    local scriptPath
    if M.isBackgroundProcessEnabled() then
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
    thread:start(scriptPath)

    state.loadingMessage = "Loading"
    state.loadingBackState = configModule.STATE_SETTINGS
    state.loadingDoneChannel = chan
    state.currentState = configModule.STATE_LOADING
    log.logMessage("Background toggle started (async)")
    return true
end

-- Synchronous fallback when threads unavailable (e.g. some embedded platforms).
function M.runToggleBackgroundProcessSync()
    local enabled = M.isBackgroundProcessEnabled()
    if enabled then
        runBackgroundScriptSync(config.UNINSTALL_BG_SCRIPT, "Disable background process")
    else
        runBackgroundScriptSync(config.INSTALL_BG_SCRIPT, "Enable background process")
    end
end

return M
