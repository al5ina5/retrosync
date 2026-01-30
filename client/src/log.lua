-- src/log.lua
-- Logging and log consolidation for RetroSync client.
-- Depends: src.config

local config = require("src.config")

local function logMessage(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = "[" .. timestamp .. "] " .. tostring(msg) .. "\n"
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)
    local file = io.open(config.LOG_FILE, "a")
    if file then
        pcall(function()
            file:write(logEntry)
            file:flush()
        end)
        file:close()
    else
        print("[LOG ERROR] Failed to open log file: " .. tostring(config.LOG_FILE))
        print(logEntry)
    end
    print(logEntry)
end

local function consolidateLogs()
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)
    local logFiles = {
        config.DATA_DIR .. "/debug.log",
        config.DATA_DIR .. "/http_resp.txt",
        config.DATA_DIR .. "/http_post.txt",
        config.DATA_DIR .. "/http_err.txt",
        config.APP_DIR .. "/log.txt",
        config.DATA_DIR .. "/watcher.log",
        config.DATA_DIR .. "/muos_autostart.log",
        "/mnt/SDCARD/Saves/spruce/retrosync.log",
    }
    local consolidated = {}
    for _, logPath in ipairs(logFiles) do
        local file = io.open(logPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            if content and content ~= "" then
                table.insert(consolidated, "=== Contents from " .. logPath .. " ===\n")
                table.insert(consolidated, content)
                table.insert(consolidated, "\n")
            end
            if logPath ~= config.LOG_FILE then
                pcall(function() os.remove(logPath) end)
            end
        end
    end
    if #consolidated > 0 then
        local file = io.open(config.LOG_FILE, "a")
        if file then
            pcall(function()
                file:write("\n=== Log consolidation at " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")
                file:write(table.concat(consolidated))
                file:write("=== End of consolidated logs ===\n\n")
                file:flush()
            end)
            file:close()
        end
    end
    local logFile = io.open(config.LOG_FILE, "r")
    if logFile then
        logFile:seek("end")
        local size = logFile:seek()
        logFile:close()
        if size > 10 * 1024 * 1024 then
            local backupLog = config.LOG_FILE .. ".old"
            pcall(function() os.execute("mv '" .. config.LOG_FILE .. "' '" .. backupLog .. "' 2>/dev/null") end)
            logMessage("Log file rotated (size: " .. size .. " bytes)")
        end
    end
end

return {
    logMessage = logMessage,
    consolidateLogs = consolidateLogs,
}
