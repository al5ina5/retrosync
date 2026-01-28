-- main.lua - RetroSync Lua Client for LÖVE 11.x
-- Shows pairing code entry, handles connection, uploads saves

-- Load JSON library
local json = require("lib.dkjson")

local SERVER_URL = "http://10.0.0.197:3002"
-- Ensure no trailing slash
if SERVER_URL:sub(-1) == "/" then
    SERVER_URL = SERVER_URL:sub(1, -2)
end

-- Get app directory (where the .love file is located)
-- Try to detect from script location or use current directory
local function getAppDirectory()
    -- Try to get from love.filesystem first
    local saveDir = love.filesystem.getSaveDirectory()
    if saveDir then
        -- For PortMaster, the app directory is usually the parent of saves
        -- But we want the actual app folder, so try to detect it
        local appDir = saveDir:match("(.*)/RetroSync")
        if appDir then
            return appDir .. "/RetroSync"
        end
    end
    
    -- Fallback: try to detect from script location or use a default
    -- For PortMaster apps, the app runs from its own directory
    -- We'll use a relative path that should work
    local defaultPath = os.getenv("PWD") or "."
    return defaultPath
end

local APP_DIR = getAppDirectory()
local DATA_DIR = APP_DIR .. "/data"
local API_KEY_FILE = DATA_DIR .. "/api_key"
local DEVICE_NAME_FILE = DATA_DIR .. "/device_name"
local CODE_FILE = DATA_DIR .. "/code"
local LOG_FILE = DATA_DIR .. "/debug.log"

-- States
local STATE_SHOWING_CODE = 1
local STATE_CONNECTED = 2
local STATE_UPLOADING = 3
local STATE_SUCCESS = 4

-- App state
local currentState = STATE_SHOWING_CODE
local apiKey = nil
local deviceName = nil
local deviceCode = nil  -- 6-digit code from server
local pairingError = ""
local uploadProgress = ""
local uploadSuccess = 0
local uploadTotal = 0
local isPaired = false

-- Timer for polling
local pollTimer = 0
local codeDisplayTimer = 0
local pollIndicator = 0  -- For visual polling indicator

local pollCount = 0

-- Font
local titleFont = nil
local codeFont = nil

function love.load()
    -- Set up graphics
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load Minecraft font with error handling
    local fontPath = "assets/Minecraft.ttf"
    local ok, err = pcall(function()
        titleFont = love.graphics.newFont(fontPath, 48)
        codeFont = love.graphics.newFont(fontPath, 32)
    end)
    if not ok then
        print("ERROR: Failed to load font from " .. fontPath .. ": " .. tostring(err))
        -- Fallback to default font
        titleFont = love.graphics.newFont(48)
        codeFont = love.graphics.newFont(32)
    end
    
    -- Create data directory within app folder (with error handling)
    pcall(function()
        os.execute("mkdir -p '" .. DATA_DIR .. "' 2>/dev/null")
    end)
    
    -- Initialize logging
    logMessage("=== RetroSync App Started ===")
    logMessage("App directory: " .. APP_DIR)
    logMessage("Data directory: " .. DATA_DIR)
    
    -- Load API key if exists (already paired)
    apiKey = loadApiKey()
    deviceName = loadDeviceName()
    
    if apiKey then
        -- Already paired, go straight to connected state
        currentState = STATE_CONNECTED
        isPaired = true
    else
        -- Not paired yet, need to get/show code
        currentState = STATE_SHOWING_CODE
        isPaired = false
        
        -- Load code from local storage, or get new one from server
        deviceCode = loadCode()
        if not deviceCode then
            -- First run - get code from server
            getCodeFromServer()
        end
    end
end

function love.update(dt)
    pollTimer = pollTimer + dt
    pollIndicator = pollIndicator + dt
    
    -- If we're showing code but don't have one yet, try to get it
    if currentState == STATE_SHOWING_CODE and not deviceCode and pollTimer >= 1 then
        pollTimer = 0
        logMessage("No device code yet, attempting to fetch...")
        getCodeFromServer()
    end
    
    -- Poll server to check if device has been paired (when showing code)
    if currentState == STATE_SHOWING_CODE and deviceCode and pollTimer >= 2 then
        pollTimer = 0
        -- Reset poll indicator to show activity
        pollIndicator = 0
        checkPairingStatus()
    end
    
    -- Poll server heartbeat every 5 seconds if connected
    if currentState == STATE_CONNECTED and pollTimer >= 5 then
        pollTimer = 0
        sendHeartbeat()
    end
end

function love.draw()
    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if currentState == STATE_SHOWING_CODE then
        -- Show RETRO SYNC title and code
        love.graphics.setFont(titleFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("RETRO SYNC", 0, 150, screenWidth, "center")
        
        love.graphics.setFont(codeFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("CODE", 0, 220, screenWidth, "center")
        love.graphics.printf(deviceCode or "------", 0, 280, screenWidth, "center")
        
        -- Show polling indicator
        local dots = math.floor(pollIndicator * 2) % 4
        local dotStr = ""
        for i = 1, dots do
            dotStr = dotStr .. "."
        end
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(codeFont)
        love.graphics.printf("Waiting" .. dotStr, 0, 350, screenWidth, "center")
        
        -- Show pairing error if any
        if pairingError ~= "" then
            love.graphics.setColor(1, 0.8, 0.4)
            love.graphics.setFont(codeFont)
            love.graphics.printf(pairingError, 0, 400, screenWidth, "center")
        end
        
    elseif currentState == STATE_CONNECTED then
        love.graphics.setColor(0.4, 1, 0.6)
        love.graphics.printf("CONNECTED!", 0, 80, screenWidth, "center")
        love.graphics.setColor(0.8, 0.8, 0.8)
        if deviceName then
            love.graphics.printf("Device: " .. deviceName, 0, 140, screenWidth, "center")
        end
        
        -- Upload button
        love.graphics.setColor(0.3, 0.3, 0.7)
        love.graphics.rectangle("fill", 170, 200, 300, 60, 10, 10)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf("[ A ] UPLOAD SAVES", 0, 215, screenWidth, "center")
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.printf("Press A to upload saves", 0, 300, screenWidth, "center")
        love.graphics.printf("Press B to exit", 0, 340, screenWidth, "center")
        
    elseif currentState == STATE_UPLOADING then
        love.graphics.setColor(1, 0.8, 0.4)
        love.graphics.printf("UPLOADING...", 0, 180, screenWidth, "center")
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(uploadProgress, 0, 240, screenWidth, "center")
        
    elseif currentState == STATE_SUCCESS then
        love.graphics.setColor(0.4, 1, 0.6)
        love.graphics.printf("UPLOAD COMPLETE!", 0, 160, screenWidth, "center")
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(uploadProgress, 0, 220, screenWidth, "center")
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf("Check dashboard: " .. SERVER_URL, 0, 280, screenWidth, "center")
        love.graphics.printf("Press B to exit", 0, 320, screenWidth, "center")
    end
    
    -- Show error if any (only for non-showing-code states)
    if pairingError ~= "" and currentState ~= STATE_SHOWING_CODE then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.setFont(codeFont)
        love.graphics.printf(pairingError, 0, 460, screenWidth, "center")
    end
end

function love.keypressed(key)
    if currentState == STATE_CONNECTED then
        if key == "a" or key == "x" then
            uploadSaves()
        elseif key == "b" or key == "escape" then
            love.event.quit()
        end
    elseif currentState == STATE_SUCCESS then
        if key == "b" or key == "escape" then
            love.event.quit()
        end
    end
end

function love.gamepadpressed(joystick, button)
    if currentState == STATE_CONNECTED then
        if button == "a" then
            uploadSaves()
        elseif button == "b" then
            love.event.quit()
        end
    elseif currentState == STATE_SUCCESS then
        if button == "b" then
            love.event.quit()
        end
    end
end

-- Get code from server (first run only)
function getCodeFromServer()
    -- Don't fetch if we already have a code
    if deviceCode then
        logMessage("getCodeFromServer: Already have code: " .. deviceCode)
        return
    end
    
    pairingError = "Getting code..."
    logMessage("=== getCodeFromServer START ===")
    logMessage("POST " .. SERVER_URL .. "/api/devices/code")
    logMessage("Request data: {\"deviceType\":\"miyoo_flip\"}")
    
    local url = SERVER_URL .. "/api/devices/code"
    local data = '{"deviceType":"miyoo_flip"}'
    
    local resp = httpPost(url, data)
    
    if resp and resp ~= "" then
        logMessage("Response received: " .. #resp .. " bytes")
        logMessage("Full response: " .. resp)
        
        local result = jsonDecode(resp)
        if result then
            logMessage("JSON decode successful")
            logMessage("  success: " .. tostring(result.success))
            logMessage("  message: " .. tostring(result.message))
            logMessage("  has data: " .. tostring(result.data ~= nil))
            if result.data then
                logMessage("  data.code: " .. tostring(result.data.code))
                logMessage("  data.expiresAt: " .. tostring(result.data.expiresAt))
            end
            
            if result.success and result.data and result.data.code then
                deviceCode = string.upper(result.data.code) -- Store uppercase
                saveCode(deviceCode)
                pairingError = ""
                logMessage("SUCCESS: Code saved: " .. deviceCode)
            else
                -- More detailed error
                if not result.success then
                    pairingError = "Error: " .. (result.message or result.error or "unknown")
                    logMessage("ERROR: API returned success=false: " .. pairingError)
                elseif not result.data then
                    pairingError = "No data in response"
                    logMessage("ERROR: No data object in response")
                elseif not result.data.code then
                    pairingError = "No code field"
                    logMessage("ERROR: data object exists but no code field")
                    logMessage("  data keys: " .. (result.data and "exists" or "nil"))
                else
                    pairingError = "Failed to get code"
                    logMessage("ERROR: Unknown failure")
                end
            end
        else
            pairingError = "Invalid JSON"
            logMessage("ERROR: JSON decode returned nil")
            logMessage("Raw response (first 500 chars): " .. resp:sub(1, 500))
        end
    else
        pairingError = "Connection failed"
        logMessage("ERROR: HTTP request returned nil or empty")
        logMessage("  Check http_err.txt for curl errors")
    end
    logMessage("=== getCodeFromServer END ===")
end

-- Check pairing status by polling /status endpoint
function checkPairingStatus()
    if not deviceCode then 
        pairingError = "No code - fetching..."
        logMessage("checkPairingStatus: No device code, will fetch on next update")
        return 
    end
    
    local url = SERVER_URL .. "/api/devices/status"
    -- Send code in uppercase for consistency
    local data = '{"code":"' .. string.upper(deviceCode) .. '"}'
    
    local resp = httpPost(url, data)
    
    if resp and resp ~= "" then
        local result = jsonDecode(resp)
        
        if result and result.success and result.data then
            local status = result.data.status
            logMessage("Status check: " .. tostring(status))
            
            if status == "paired" then
                -- Device is paired! Get API key
                if result.data.apiKey then
                    apiKey = result.data.apiKey
                    if result.data.device and result.data.device.name then
                        deviceName = result.data.device.name
                    else
                        deviceName = "Miyoo Flip"
                    end
                    saveApiKey(apiKey)
                    saveDeviceName(deviceName)
                    currentState = STATE_CONNECTED
                    isPaired = true
                    pairingError = ""
                    logMessage("SUCCESS: Device paired! API key saved.")
                else
                    pairingError = "No API key"
                    logMessage("ERROR: Status=paired but no API key")
                end
            elseif status == "waiting" then
                -- Code exists but not linked to user yet, keep waiting
                pairingError = ""
            else
                -- Unknown status or error
                pairingError = result.data.message or result.message or "Waiting..."
                logMessage("Status: " .. tostring(status) .. " - " .. pairingError)
            end
        else
            -- Failed to parse or error response
            pairingError = (result and result.message) or "Invalid response"
            logMessage("ERROR: Status check failed - " .. pairingError)
        end
    else
        -- No response from server
        pairingError = "No response"
        logMessage("ERROR: Status check - no HTTP response")
    end
end

-- HTTP helper using curl via os.execute
function httpGet(url, headers)
    local tmpfile = "/tmp/retrosync_resp.txt"
    local headerStr = ""
    if headers then
        for k, v in pairs(headers) do
            headerStr = headerStr .. " -H '" .. k .. ": " .. v .. "'"
        end
    end
    local ok, err = pcall(function()
        os.execute("curl -s" .. headerStr .. " '" .. url .. "' > " .. tmpfile .. " 2>/dev/null")
    end)
    if not ok then return nil end
    
    local file = io.open(tmpfile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        pcall(function() os.execute("rm " .. tmpfile .. " 2>/dev/null") end)
        return content
    end
    return nil
end

function httpPost(url, data, headers)
    local logDir = "/mnt/SDCARD/Saves/retrosync"
    local tmpfile = logDir .. "/http_resp.txt"
    local postfile = logDir .. "/http_post.txt"
    local errfile = logDir .. "/http_err.txt"
    
    -- Ensure log directory exists
    pcall(function()
        os.execute("mkdir -p " .. logDir .. " 2>/dev/null")
    end)
    
    logMessage("httpPost: " .. url)
    logMessage("  Data: " .. data:sub(1, 100))
    
    local f = io.open(postfile, "w")
    if f then
        f:write(data)
        f:close()
    else
        logMessage("ERROR: Failed to write post file to " .. postfile)
        return nil
    end
    
    local headerStr = "-H 'Content-Type: application/json'"
    if headers then
        for k, v in pairs(headers) do
            headerStr = headerStr .. " -H '" .. k .. ": " .. v .. "'"
        end
    end
    
    -- Use curl with timeout and better error handling
    -- Escape single quotes in URL if needed
    local escapedUrl = url:gsub("'", "'\\''")
    local cmd = "curl -s -m 10 -X POST " .. headerStr .. " -d @" .. postfile .. " '" .. escapedUrl .. "' > " .. tmpfile .. " 2>" .. errfile
    logMessage("  Command: curl -s -m 10 -X POST ...")
    
    local ok, err = pcall(function()
        local result = os.execute(cmd)
        return result
    end)
    
    if not ok then
        logMessage("ERROR: curl command failed: " .. tostring(err))
        return nil
    end
    
    -- Check for errors
    local errf = io.open(errfile, "r")
    if errf then
        local errContent = errf:read("*all")
        errf:close()
        if errContent and errContent ~= "" then
            logMessage("curl stderr: " .. errContent)
        end
    end
    
    local file = io.open(tmpfile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        -- Trim whitespace
        if content then
            content = content:match("^%s*(.-)%s*$")
        end
        
        if content and content ~= "" then
            logMessage("  Response: " .. content:sub(1, 200))
        else
            logMessage("  Response: (empty)")
        end
        
        return content
    else
        logMessage("ERROR: Failed to read response file: " .. tmpfile)
    end
    return nil
end

-- pairDevice function removed - auto-pair endpoint handles everything

function sendHeartbeat()
    if not apiKey then return end
    
    local headers = {["X-API-Key"] = apiKey}
    httpPost(SERVER_URL .. "/api/sync/heartbeat", "{}", headers)
end

function uploadSaves()
    if not apiKey then
        currentState = STATE_SHOWING_CODE
        return
    end
    
    currentState = STATE_UPLOADING
    uploadProgress = "Finding save files..."
    
    -- Find save files using shell commands (LOVE2D filesystem doesn't work with absolute paths)
    local saveFiles = findSaveFiles()
    
    if #saveFiles == 0 then
        uploadProgress = "No save files found"
        currentState = STATE_CONNECTED
        return
    end
    
    uploadTotal = math.min(#saveFiles, 20)
    uploadSuccess = 0
    
    for i, filepath in ipairs(saveFiles) do
        if i > 20 then break end
        
        uploadProgress = string.format("Uploading %d/%d...", i, uploadTotal)
        
        local ok = uploadSave(filepath)
        if ok then
            uploadSuccess = uploadSuccess + 1
        end
    end
    
    uploadProgress = string.format("Uploaded %d/%d files", uploadSuccess, uploadTotal)
    currentState = STATE_SUCCESS
end

function uploadSave(filepath)
    if not apiKey then return false end
    
    local filename = filepath:match("/([^/]+)$") or filepath
    local fileSize = 0
    
    -- Get file size
    local f = io.open(filepath, "r")
    if f then
        f:seek("end")
        fileSize = f:seek()
        f:close()
    end
    
    -- Log the sync event (simplified - just log metadata)
    local headers = {["X-API-Key"] = apiKey}
    local data = '{"filePath":"' .. filename .. '","fileSize":' .. fileSize .. ',"action":"upload"}'
    local resp = httpPost(SERVER_URL .. "/api/sync/files", data, headers)
    
    if resp then
        local result = jsonDecode(resp)
        return result and result.success
    end
    return false
end

function findSaveFiles()
    local files = {}
    
    -- Use shell to find save files (LOVE2D filesystem is sandboxed)
    local locations = {
        "/mnt/SDCARD/Roms",
        "/mnt/SDCARD/Saves",
        "/mnt/SDCARD/RetroArch/saves"
    }
    
    for _, loc in ipairs(locations) do
        -- Use find command to locate save files
        local cmd = "find " .. loc .. " -type f \\( -name '*.sav' -o -name '*.state' -o -name '*.save' -o -name '*.bak' \\) 2>/dev/null | head -20"
        local handle = io.popen(cmd)
        if handle then
            for line in handle:lines() do
                table.insert(files, line)
            end
            handle:close()
        end
    end
    
    return files
end

function loadCode()
    local file = io.open(CODE_FILE, "r")
    if file then
        local code = file:read("*line")
        file:close()
        if code then
            return string.upper(code) -- Ensure uppercase
        end
    end
    return nil
end

function saveCode(code)
    local file = io.open(CODE_FILE, "w")
    if file then
        file:write(code)
        file:close()
    end
end

function loadApiKey()
    local file = io.open(API_KEY_FILE, "r")
    if file then
        local key = file:read("*line")
        file:close()
        return key
    end
    return nil
end

function saveApiKey(key)
    local file = io.open(API_KEY_FILE, "w")
    if file then
        file:write(key)
        file:close()
    end
end

function loadDeviceName()
    local file = io.open(DEVICE_NAME_FILE, "r")
    if file then
        local name = file:read("*line")
        file:close()
        return name
    end
    return nil
end

function saveDeviceName(name)
    local file = io.open(DEVICE_NAME_FILE, "w")
    if file then
        file:write(name)
        file:close()
    end
end

-- Simple JSON decode - extract specific fields we need
function jsonDecode(str)
    if not str or str == "" then return nil end
    
    local result = {}
    result.data = {}
    
    -- Extract success (true/false) - try multiple patterns
    -- Pattern 1: "success":true (no spaces)
    local success = str:match('"success":(true)')
    if not success then
        -- Pattern 2: "success": false (with space)
        success = str:match('"success":%s*(true)')
    end
    if not success then
        -- Pattern 3: "success" : true (space before colon)
        success = str:match('"success"%s*:%s*(true)')
    end
    if not success then
        -- Try false
        success = str:match('"success":(false)')
    end
    if not success then
        success = str:match('"success":%s*(false)')
    end
    if success then
        result.success = (success == "true")
    end
    
    -- Extract message
    local message = str:match('"message"%s*:%s*"([^"]+)"')
    if message then
        result.message = message
    end
    
    -- Find the data object section
    local dataIdx = str:find('"data"%s*:%s*%{')
    if dataIdx then
        -- Extract everything after "data":{
        local afterData = str:sub(dataIdx)
        
        -- Find the matching closing brace for the data object
        local braceCount = 0
        local dataStart = afterData:find('%{')
        local dataEnd = dataStart
        if dataStart then
            for i = dataStart, #afterData do
                local char = afterData:sub(i, i)
                if char == '{' then
                    braceCount = braceCount + 1
                elseif char == '}' then
                    braceCount = braceCount - 1
                    if braceCount == 0 then
                        dataEnd = i
                        break
                    end
                end
            end
            if dataEnd > dataStart then
                local dataSection = afterData:sub(dataStart, dataEnd)
                
                -- Extract code from data object (6-character alphanumeric)
                -- Try multiple patterns to be more flexible
                local code = dataSection:match('"code":%s*"([A-Z0-9]{6})"')
                if not code then
                    code = dataSection:match('"code"%s*:%s*"([A-Z0-9]{6})"')
                end
                if not code then
                    -- Fallback: match any 6 characters
                    code = dataSection:match('"code":%s*"([^"]{6})"')
                end
                if code then
                    result.data.code = code
                end
                
                -- Extract status (waiting, paired)
                local status = dataSection:match('"status"%s*:%s*"([^"]+)"')
                if status then
                    result.data.status = status
                end
                
                -- Extract apiKey from data object
                local apiKey = dataSection:match('"apiKey"%s*:%s*"([^"]+)"')
                if apiKey then
                    result.data.apiKey = apiKey
                end
                
                -- Extract expiresAt
                local expiresAt = dataSection:match('"expiresAt"%s*:%s*"([^"]+)"')
                if expiresAt then
                    result.data.expiresAt = expiresAt
                end
                
                -- Extract device.name from nested device object
                local deviceStart = dataSection:find('"device"%s*:%s*%{')
                if deviceStart then
                    local deviceBraceCount = 0
                    local deviceEnd = deviceStart
                    for i = deviceStart, #dataSection do
                        local char = dataSection:sub(i, i)
                        if char == '{' then
                            deviceBraceCount = deviceBraceCount + 1
                        elseif char == '}' then
                            deviceBraceCount = deviceBraceCount - 1
                            if deviceBraceCount == 0 then
                                deviceEnd = i
                                break
                            end
                        end
                    end
                    if deviceEnd > deviceStart then
                        local deviceSection = dataSection:sub(deviceStart, deviceEnd)
                        local deviceName = deviceSection:match('"name"%s*:%s*"([^"]+)"')
                        if deviceName then
                            result.data.device = { name = deviceName }
                        end
                    end
                end
            end
        end
    end
    
    -- Fallback: if data section not found or code not extracted, try global search
    if not result.data.code then
        -- Look for "code" anywhere in the JSON (6 alphanumeric chars)
        local code = str:match('"code":%s*"([A-Z0-9]{6})"')
        if not code then
            code = str:match('"code"%s*:%s*"([A-Z0-9]{6})"')
        end
        if not code then
            -- Last resort: any 6 characters
            code = str:match('"code":%s*"([^"]{6})"')
        end
        if code then
            result.data.code = code
        end
    end
    
    -- Fallback for apiKey
    if not result.data.apiKey then
        local apiKey = str:match('"apiKey"%s*:%s*"([^"]+)"')
        if apiKey then
            result.data.apiKey = apiKey
        end
    end
    
    return result
end

-- Logging function - writes to log file in app directory
function logMessage(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = "[" .. timestamp .. "] " .. tostring(msg) .. "\n"
    
    local file = io.open(LOG_FILE, "a")
    if file then
        file:write(logEntry)
        file:close()
    end
    -- Also print to console if available
    print(logEntry)
end
