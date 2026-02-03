-- src/config.lua
-- Paths, constants, and default server URL for RetroSync client.
-- No mutable state. Other modules require "src.config" for paths and state enums.

local M = {}

local function getAppDirectory()
    -- On macOS fused .app, always use the app bundle so DATA_DIR works from any folder (Downloads, etc.).
    if love and love.filesystem and love.filesystem.getSource and love.system and love.system.getOS and love.system.getOS() == "OS X" then
        local source = love.filesystem.getSource()
        if source and source ~= "" and not source:match("%.love$") then
            return source
        end
    end
    local pwd = os.getenv("PWD")
    if pwd and pwd ~= "" and pwd ~= "/" then
        return pwd
    end
    local source = love.filesystem.getSource()
    if source and source ~= "" then
        if source:match("%.love$") then
            return source:match("(.*)/")
        end
        return source
    end
    return "."
end

M.APP_DIR = getAppDirectory()
-- Use LÖVE's save directory for all platforms (writable, cross-platform).
-- e.g. macOS: ~/Library/Application Support/LOVE/retrosync, Windows: %userprofile%\AppData\Local\LOVE\retrosync, Linux: ~/.local/share/love/retrosync
if love and love.filesystem and love.filesystem.getSaveDirectory then
    M.DATA_DIR = love.filesystem.getSaveDirectory()
else
    M.DATA_DIR = M.APP_DIR .. "/data"
end
-- Single config file: all settings, deviceHistory, scanPaths. No other config files.
M.CONFIG_FILE = M.DATA_DIR .. "/config.json"
M.LOGS_DIR = M.DATA_DIR .. "/logs"
M.WATCHER_DIR = M.DATA_DIR .. "/watcher"  -- watcher.pid, watcher_state.tsv; temp files; logs go in logs/
M.MAX_LOG_FILE_BYTES = 2 * 1024 * 1024  -- 2MB per day file before rotation
M.INSTALL_BG_SCRIPT = M.APP_DIR .. "/install-background-process.sh"
M.UNINSTALL_BG_SCRIPT = M.APP_DIR .. "/uninstall-background-process.sh"

M.STATE_SHOWING_CODE = 1
M.STATE_CONNECTED = 2
M.STATE_UPLOADING = 3
M.STATE_SUCCESS = 4
M.STATE_SHOWING_FILES = 5
M.STATE_DOWNLOADING = 6
M.STATE_SETTINGS = 7
M.STATE_CONFIRM = 8
M.STATE_LOADING = 9

M.SERVER_URL = "https://retrosync.vercel.app"
if M.SERVER_URL:sub(-1) == "/" then
    M.SERVER_URL = M.SERVER_URL:sub(1, -2)
end

M.PATH_ADDED_DURATION = 2
M.inputDebounceThreshold = 0.08
M.homeIntroDuration = 0.9
M.codeIntroDuration = 0.9
M.HTTP_GET_TIMEOUT = 30
M.MIN_VALID_TIMESTAMP = 1420070400
M.MAX_VALID_TIMESTAMP = 2051222400
M.MAX_HISTORY_ENTRIES = 100
M.MTIME_TOLERANCE_MS = 65000  -- upload; download uses 10min in code

return M
