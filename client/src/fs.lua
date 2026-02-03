-- src/fs.lua
-- File mtime get/set, ensureParentDir, findSaveFiles, path normalizers, wipeDirectory.
-- Depends: config, log, state

local config = require("src.config")
local log = require("src.log")
local state = require("src.state")
local scan_paths = require("src.scan_paths")

local M = {}

local function isValidTimestamp(ts)
    if not ts or type(ts) ~= "number" then return false end
    return ts >= config.MIN_VALID_TIMESTAMP and ts <= config.MAX_VALID_TIMESTAMP
end

local function getFileMtimeSeconds(path)
    if not path or path == "" then
        log.logMessage("getFileMtimeSeconds: Invalid path (nil or empty)")
        return nil
    end
    local escaped = path:gsub("'", "'\\''")
    
    -- Try method 0: date -r file +%s (works on SpruceOS/BusyBox)
    -- This is the most reliable method for embedded Linux systems
    local cmd0 = "date -r '" .. escaped .. "' +%s 2>/dev/null"
    local h0 = io.popen(cmd0)
    if h0 then
        local out0 = h0:read("*all") or ""
        pcall(function() h0:close() end)
        out0 = out0:match("^%s*(%d+)")
        local mtime0 = tonumber(out0)
        if mtime0 and mtime0 > 0 then
            if isValidTimestamp(mtime0) then
                log.logMessage("getFileMtimeSeconds: Success with date -r method - mtime = " .. mtime0 .. " seconds")
                return mtime0
            else
                log.logMessage("getFileMtimeSeconds: CORRUPTED timestamp detected (date -r): " .. mtime0 .. " (" .. os.date("%Y-%m-%d", mtime0) .. ") - returning nil for size-based comparison")
                return nil
            end
        end
    end
    
    -- Try method 1: stat -c %Y (GNU stat)
    local cmd1 = "stat -c %Y '" .. escaped .. "' 2>/dev/null"
    local h1 = io.popen(cmd1)
    if h1 then
        local out1 = h1:read("*all") or ""
        pcall(function() h1:close() end)
        out1 = out1:match("^%s*(.-)%s*$")
        local mtime1 = tonumber(out1)
        if mtime1 then
            if isValidTimestamp(mtime1) then
                log.logMessage("getFileMtimeSeconds: Success with GNU stat method - mtime = " .. mtime1 .. " seconds")
                return mtime1
            else
                log.logMessage("getFileMtimeSeconds: CORRUPTED timestamp detected (GNU stat): " .. mtime1 .. " - returning nil")
                return nil
            end
        end
    end
    
    -- Try method 2: stat -t (POSIX stat, returns timestamp as last field)
    local cmd2 = "stat -t '" .. escaped .. "' 2>/dev/null"
    log.logMessage("getFileMtimeSeconds: Trying method 2 (POSIX stat): " .. cmd2)
    local h2 = io.popen(cmd2)
    if h2 then
        local out2 = h2:read("*all") or ""
        pcall(function() h2:close() end)
        -- stat -t output format: filename size blocks mode uid gid rdev mtime
        -- Extract mtime (last field)
        local fields = {}
        for field in out2:gmatch("%S+") do
            table.insert(fields, field)
        end
        if #fields >= 8 then
            local mtime2 = tonumber(fields[8]) -- mtime is 8th field
            if mtime2 then
                if isValidTimestamp(mtime2) then
                    log.logMessage("getFileMtimeSeconds: Success with method 2 - mtime = " .. mtime2 .. " seconds")
                    return mtime2
                else
                    log.logMessage("getFileMtimeSeconds: CORRUPTED timestamp detected (POSIX stat): " .. mtime2 .. " - returning nil")
                    return nil
                end
            end
        end
        log.logMessage("getFileMtimeSeconds: Method 2 failed, output: '" .. tostring(out2) .. "'")
    end
    
    -- Try method 3: ls -l and parse (works on most systems)
    local cmd3 = "ls -l '" .. escaped .. "' 2>/dev/null"
    log.logMessage("getFileMtimeSeconds: Trying method 3 (ls -l): " .. cmd3)
    local h3 = io.popen(cmd3)
    if h3 then
        local out3 = h3:read("*all") or ""
        pcall(function() h3:close() end)
        -- ls -l format: -rw-r--r-- 1 user group size MMM DD HH:MM filename (recent)
        --              -rw-r--r-- 1 user group size MMM DD YYYY filename (old)
        -- Parse: skip first 5 fields (perms, links, user, group, size), then date
        local monthStr, dayStr, timeOrYear = out3:match("%S+%s+%d+%s+%S+%s+%S+%s+%d+%s+(%w+)%s+(%d+)%s+(%S+)")
        if monthStr and dayStr and timeOrYear then
            log.logMessage("getFileMtimeSeconds: Method 3 parsed: month=" .. monthStr .. ", day=" .. dayStr .. ", timeOrYear=" .. timeOrYear)
            
            -- Month name to number
            local monthMap = {
                Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
                Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
            }
            local month = monthMap[monthStr]
            local day = tonumber(dayStr)
            
            if month and day then
                local year, hour, min
                
                -- Check if timeOrYear is HH:MM (recent file) or YYYY (old file)
                if timeOrYear:match("^%d%d:%d%d$") then
                    -- Recent file: HH:MM format
                    hour, min = timeOrYear:match("(%d%d):(%d%d)")
                    hour = tonumber(hour)
                    min = tonumber(min)
                    
                    -- Get current year/month/day
                    local now = os.time()
                    local currentYear = tonumber(os.date("%Y", now))
                    local currentMonth = tonumber(os.date("%m", now))
                    local currentDay = tonumber(os.date("%d", now))
                    
                    -- If the file's month/day is in the future relative to today, assume last year
                    year = currentYear
                    if month > currentMonth or (month == currentMonth and day > currentDay) then
                        year = currentYear - 1
                        log.logMessage("getFileMtimeSeconds: File date appears to be last year (month=" .. month .. " > current=" .. currentMonth .. ")")
                    end
                    
                    log.logMessage("getFileMtimeSeconds: Parsed as recent file: " .. year .. "-" .. month .. "-" .. day .. " " .. hour .. ":" .. min)
                else
                    -- Old file: YYYY format
                    year = tonumber(timeOrYear)
                    hour = 0
                    min = 0
                    log.logMessage("getFileMtimeSeconds: Parsed as old file: " .. year .. "-" .. month .. "-" .. day)
                end
                
                if year and month and day and hour and min then
                    -- Use os.time to convert to epoch seconds
                    local timeTable = {
                        year = year,
                        month = month,
                        day = day,
                        hour = hour,
                        min = min,
                        sec = 0
                    }
                    local mtime3 = os.time(timeTable)
                    if mtime3 and mtime3 > 0 then
                        if isValidTimestamp(mtime3) then
                            log.logMessage("getFileMtimeSeconds: Success with method 3 - mtime = " .. mtime3 .. " seconds (" .. os.date("%Y-%m-%d %H:%M:%S", mtime3) .. ")")
                            return mtime3
                        else
                            log.logMessage("getFileMtimeSeconds: CORRUPTED timestamp detected (ls -l): " .. mtime3 .. " - returning nil")
                            return nil
                        end
                    else
                        log.logMessage("getFileMtimeSeconds: os.time() failed for parsed date")
                    end
                end
            else
                log.logMessage("getFileMtimeSeconds: Failed to parse month/day from: " .. monthStr .. " " .. dayStr)
            end
        else
            log.logMessage("getFileMtimeSeconds: Method 3 failed to match date pattern, output: '" .. tostring(out3) .. "'")
        end
    end
    
    -- Try method 4: BusyBox stat format (stat file | grep Modify, then convert with date)
    local cmd4 = "stat '" .. escaped .. "' 2>/dev/null | grep -i modify"
    log.logMessage("getFileMtimeSeconds: Trying method 4 (BusyBox stat | grep): " .. cmd4)
    local h4 = io.popen(cmd4)
    if h4 then
        local out4 = h4:read("*all") or ""
        pcall(function() h4:close() end)
        -- Parse "Modify: 2026-01-28 17:05:19.123456789 +0000" or "Modify: 2026-01-28 17:05:19"
        local dateStr = out4:match("Modify:%s+(%S+%s+%S+)")
        if dateStr then
            log.logMessage("getFileMtimeSeconds: Method 4 found date string: " .. tostring(dateStr))
            -- Try to convert using date command (GNU date format)
            local cmd4b = "date -d '" .. dateStr .. "' +%s 2>/dev/null"
            log.logMessage("getFileMtimeSeconds: Trying date conversion (GNU): " .. cmd4b)
            local h4b = io.popen(cmd4b)
            if h4b then
                local out4b = h4b:read("*all") or ""
                pcall(function() h4b:close() end)
                out4b = out4b:match("^%s*(.-)%s*$")
                local mtime4 = tonumber(out4b)
                if mtime4 and mtime4 > 0 then
                    if isValidTimestamp(mtime4) then
                        log.logMessage("getFileMtimeSeconds: Success with method 4 - mtime = " .. mtime4 .. " seconds")
                        return mtime4
                    else
                        log.logMessage("getFileMtimeSeconds: CORRUPTED timestamp detected (method 4): " .. mtime4 .. " - returning nil")
                        return nil
                    end
                end
            end
            local cmd4c = "date -D '%Y-%m-%d %H:%M:%S' -d '" .. dateStr .. "' +%s 2>/dev/null"
            local h4c = io.popen(cmd4c)
            if h4c then
                local out4c = h4c:read("*all") or ""
                pcall(function() h4c:close() end)
                out4c = out4c:match("^%s*(.-)%s*$")
                local mtime4c = tonumber(out4c)
                if mtime4c and mtime4c > 0 then
                    if isValidTimestamp(mtime4c) then
                        log.logMessage("getFileMtimeSeconds: Success with method 4 (BusyBox date) - mtime = " .. mtime4c .. " seconds")
                        return mtime4c
                    else
                        log.logMessage("getFileMtimeSeconds: CORRUPTED timestamp detected (BusyBox date): " .. mtime4c .. " - returning nil")
                        return nil
                    end
                end
            end
        end
        log.logMessage("getFileMtimeSeconds: Method 4 failed, output: '" .. tostring(out4) .. "'")
    end
    log.logMessage("getFileMtimeSeconds: All methods failed for path: " .. tostring(path))
    return nil
end

local function setFileMtimeSeconds(path, sec)
    if not path or path == "" or not sec or sec <= 0 then return false end
    local escaped = path:gsub("'", "'\\''")
    local cmd = "touch -d '@" .. tostring(math.floor(sec)) .. "' '" .. escaped .. "' 2>/dev/null"
    local ok = os.execute(cmd)
    if ok == 0 then
        log.logMessage("setFileMtimeSeconds: Set mtime for " .. tostring(path) .. " to " .. tostring(sec))
        return true
    end
    log.logMessage("setFileMtimeSeconds: Failed to set mtime for " .. tostring(path))
    return false
end

local function ensureParentDir(path)
    if not path or path == "" then return end
    local dir = path:match("^(.*)/[^/]+$") or nil
    if dir and dir ~= "" then
        local escaped = dir:gsub("'", "'\\''")
        pcall(function() os.execute("mkdir -p '" .. escaped .. "' 2>/dev/null") end)
    end
end

local function normalizePathForMatch(path)
    if not path or path == "" then return path end
    return path:gsub("/%.netplay/", "/")
end

local function normalizeBatterySaveKeyForMatch(name)
    if not name or name == "" then return name end
    if name:sub(-4) == ".srm" then
        return name:sub(1, -5) .. ".sav"
    end
    return name
end

local function findSaveFiles()
    local files = {}
    local seen = {}

    local function shellQuote(s)
        -- Safely quote for POSIX shell using single quotes
        -- abc'def => 'abc'\''def'
        if not s then return "''" end
        return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
    end

    local function dirExists(path)
        local cmd = "test -d " .. shellQuote(path) .. " && echo 1 || echo 0"
        local h = io.popen(cmd)
        if not h then return false end
        local out = h:read("*all") or ""
        pcall(function() h:close() end)
        return out:match("1") ~= nil
    end
    
    -- Use shell to find save files (LOVE2D filesystem is sandboxed)
    -- Only battery saves (.sav/.srm), no .bak files, no save states
    local locations = {}
    for _, e in ipairs(scan_paths.getScanPaths(state)) do
        if e and e.path and e.path ~= "" then
            table.insert(locations, e.path)
        end
    end

    log.logMessage("findSaveFiles: Searching " .. #locations .. " locations")
    
    for idx, loc in ipairs(locations) do
        log.logMessage("findSaveFiles: Searching location " .. idx .. ": " .. loc)
        if not dirExists(loc) then
            log.logMessage("findSaveFiles: Location does not exist, skipping: " .. loc)
            goto continue_location
        end

        -- Use find command to locate only battery save files (.sav and .srm), excluding .bak and .state files
        local cmd =
            "find " .. shellQuote(loc) ..
            " -type f \\( -name '*.sav' -o -name '*.srm' \\) ! -name '*.bak' 2>/dev/null"
        log.logMessage("findSaveFiles: Command: " .. cmd)
        
        local ok, err = pcall(function()
            log.logMessage("findSaveFiles: Opening pipe for location " .. idx)
            local handle = io.popen(cmd)
            if handle then
                log.logMessage("findSaveFiles: Pipe opened, reading lines")
                local lineCount = 0
                for line in handle:lines() do
                    if line and line ~= "" then
                        if not seen[line] then
                            seen[line] = true
                            table.insert(files, line)
                        end
                        lineCount = lineCount + 1
                        log.logMessage("findSaveFiles: Found file " .. lineCount .. " in " .. loc .. ": " .. line)
                    end
                end
                log.logMessage("findSaveFiles: Read " .. lineCount .. " files from " .. loc)
                log.logMessage("findSaveFiles: Closing handle for location " .. idx)
                local closeOk, closeErr = pcall(function() handle:close() end)
                if not closeOk then
                    log.logMessage("findSaveFiles: Error closing handle: " .. tostring(closeErr))
                else
                    log.logMessage("findSaveFiles: Handle closed successfully")
                end
            else
                log.logMessage("findSaveFiles: Failed to open pipe for location " .. idx)
            end
        end)
        
        if not ok then
            log.logMessage("findSaveFiles: CRASH searching location " .. loc .. ": " .. tostring(err))
            log.logMessage("findSaveFiles: Stack trace: " .. debug.traceback())
        else
            log.logMessage("findSaveFiles: Completed search for location " .. idx .. " without errors")
        end

        ::continue_location::
    end
    
    log.logMessage("findSaveFiles: Total files found: " .. #files)
    log.logMessage("=== findSaveFiles END ===")
    return files
end

-- Wipe a directory entirely (remove all contents and the dir, then recreate).
-- Uses config.DATA_DIR from caller; on LÖVE that is getSaveDirectory(), else APP_DIR/data.
-- Cross-platform: Unix rm -rf + mkdir -p; Windows rmdir /s /q + mkdir.
local function wipeDirectory(dirPath)
    if not dirPath or dirPath == "" then
        log.logMessage("wipeDirectory: No path given, skipping")
        return
    end
    log.logMessage("wipeDirectory: Wiping data directory: " .. dirPath)
    local isWindows = love and love.system and love.system.getOS and love.system.getOS() == "Windows"
    if isWindows then
        local winPath = dirPath:gsub("/", "\\")
        local quoted = '"' .. winPath:gsub('"', '\\"') .. '"'
        pcall(function() os.execute("rmdir /s /q " .. quoted .. " 2>nul") end)
        pcall(function() os.execute("mkdir " .. quoted .. " 2>nul") end)
    else
        local escaped = dirPath:gsub("'", "'\\''")
        pcall(function() os.execute("rm -rf '" .. escaped .. "' 2>/dev/null") end)
        pcall(function() os.execute("mkdir -p '" .. escaped .. "' 2>/dev/null") end)
    end
    log.logMessage("wipeDirectory: Done")
end

M.getFileMtimeSeconds = getFileMtimeSeconds
M.setFileMtimeSeconds = setFileMtimeSeconds
M.ensureParentDir = ensureParentDir
M.normalizePathForMatch = normalizePathForMatch
M.normalizeBatterySaveKeyForMatch = normalizeBatterySaveKeyForMatch
M.findSaveFiles = findSaveFiles
M.wipeDirectory = wipeDirectory

return M
