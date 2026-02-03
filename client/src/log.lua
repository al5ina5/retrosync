-- src/log.lua
-- Logging to data/logs/YYYY-MM-DD.log with size cap. Single log stream; no ephemeral merge.
-- Depends: src.config

local config = require("src.config")

local function getLogPath()
    local dateStr = os.date("%Y-%m-%d")
    return config.LOGS_DIR .. "/" .. dateStr .. ".log"
end

local function ensureLogsDir()
    pcall(function()
        local dir = config.LOGS_DIR:gsub("'", "'\\''")
        os.execute("mkdir -p '" .. dir .. "' 2>/dev/null")
    end)
end

local function maybeRotate(logPath)
    local f = io.open(logPath, "r")
    if not f then return end
    local size = f:seek("end")
    f:close()
    if size and size >= (config.MAX_LOG_FILE_BYTES or (2 * 1024 * 1024)) then
        local rotPath = logPath:gsub("%.log$", ".1.log")
        pcall(function()
            os.execute("mv '" .. logPath:gsub("'", "'\\''") .. "' '" .. rotPath:gsub("'", "'\\''") .. "' 2>/dev/null")
        end)
    end
end

function logMessage(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = "[" .. timestamp .. "] " .. tostring(msg) .. "\n"
    ensureLogsDir()
    local logPath = getLogPath()
    maybeRotate(logPath)
    local file = io.open(logPath, "a")
    if file then
        pcall(function()
            file:write(logEntry)
            file:flush()
        end)
        file:close()
    else
        print("[LOG ERROR] Failed to open " .. tostring(logPath))
        print(logEntry)
    end
    print(logEntry)
end

-- One-time: move old data/debug.log into today's log so we don't lose history. No merge of http/temp files.
function migrateLegacyLog()
    ensureLogsDir()
    local legacyPath = config.DATA_DIR .. "/debug.log"
    local file = io.open(legacyPath, "r")
    if not file then return end
    local content = file:read("*all")
    file:close()
    if not content or content == "" then
        pcall(function() os.remove(legacyPath) end)
        return
    end
    local logPath = getLogPath()
    local out = io.open(logPath, "a")
    if out then
        pcall(function()
            out:write("\n=== Migrated from data/debug.log ===\n")
            out:write(content)
            out:write("\n=== End migrated log ===\n\n")
            out:flush()
        end)
        out:close()
    end
    pcall(function() os.remove(legacyPath) end)
end

return {
    logMessage = logMessage,
    migrateLegacyLog = migrateLegacyLog,
}
