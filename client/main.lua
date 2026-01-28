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
-- For PortMaster apps, the launcher script sets GAMEDIR and cd's into it
-- So the current working directory should be the app directory
local function getAppDirectory()
    -- Try to get current working directory (PortMaster launcher sets this)
    local pwd = os.getenv("PWD")
    if pwd and pwd ~= "" and pwd ~= "/" then
        return pwd
    end
    
    -- Fallback: try to get from love.filesystem
    -- For .love files, getSource() returns the .love file path
    local source = love.filesystem.getSource()
    if source and source ~= "" then
        -- If it's a .love file, get the directory
        if source:match("%.love$") then
            return source:match("(.*)/")
        end
        return source
    end
    
    -- Last resort: use current directory
    return "."
end

local APP_DIR = getAppDirectory()
local DATA_DIR = APP_DIR .. "/data"
local API_KEY_FILE = DATA_DIR .. "/api_key"
local DEVICE_NAME_FILE = DATA_DIR .. "/device_name"
local CODE_FILE = DATA_DIR .. "/code"
local LOG_FILE = DATA_DIR .. "/debug.log"
local SERVER_URL_FILE = DATA_DIR .. "/server_url"

-- States
local STATE_SHOWING_CODE = 1
local STATE_CONNECTED = 2
local STATE_UPLOADING = 3
local STATE_SUCCESS = 4
local STATE_SHOWING_FILES = 5
local STATE_DOWNLOADING = 6

-- App state
local currentState = STATE_SHOWING_CODE
local apiKey = nil
local deviceName = nil
local deviceCode = nil  -- 6-digit code from server
local pairingError = ""
local uploadProgress = ""
local uploadSuccess = 0
local uploadTotal = 0
local downloadProgress = ""
local downloadSuccess = 0
local downloadTotal = 0
local isPaired = false
local uploadCancelled = false  -- Flag to cancel upload
local uploadPending = false  -- Flag to defer upload to next frame
local uploadJustStarted = false  -- Flag to prevent immediate cancellation
local uploadDiscoverPending = false  -- Show SYNCING first frame, then discover files
local uploadInProgress = false  -- Per-file upload phase (one file per frame)
local uploadQueue = {}  -- Paths to upload (filled after discover)
local uploadNextIndex = 1  -- Next file to upload (1-based)
local uploadFailedFiles = {}  -- {index, path, reason} for logging

-- Download state
local downloadCancelled = false
local downloadPending = false  -- Flag to defer manifest fetch to next frame
local downloadInProgress = false  -- Per-file download phase (one file per frame)
local downloadQueue = {}  -- {localPath, saveVersionId, cloudMs, displayName}
local downloadNextIndex = 1
local downloadFailedFiles = {}

-- Per-sync-session summary flags (for final UI)
local syncSessionHadUpload = false
local syncSessionHadDownload = false

-- Files list state
local savesList = {}  -- Array of save file objects
local filesListScroll = 0  -- Scroll position in the files list
local filesListSelectedIndex = 1  -- Currently selected item index (1-based)
local filesListLoading = false  -- Whether we're loading the files list
local filesListError = ""  -- Error message for files list
local filesListPending = false  -- Flag to defer API call to next frame (so screen renders first)

-- Home menu selection (CONNECTED state)
local homeSelectedIndex = 1  -- 1 = Sync, 2 = Recent

-- Home intro animation (CONNECTED)
local homeIntroTimer = 0
local homeIntroDuration = 0.9  -- slow down intro for more impact

-- Timer for polling
local pollTimer = 0
local codeDisplayTimer = 0
local pollIndicator = 0  -- For visual polling indicator
local uploadStartTimer = 0  -- Timer to prevent immediate cancellation

local pollCount = 0

-- Font
local titleFont = nil       -- General headings (Minecraft)
local codeFont = nil        -- Primary UI text (Minecraft)
local largeCountFont = nil  -- Big numbers (Minecraft)
local deviceFont = nil      -- Small labels (Minecraft)
local logoFont = nil        -- Main title "RETROSYNC" (Super Meatball)

function love.load()
    -- Set up graphics
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load fonts with error handling
    local fontPath = "assets/Minecraft.ttf"
    local logoFontPath = "assets/Super Meatball.ttf"
    local ok, err = pcall(function()
        -- Base Minecraft fonts
        titleFont = love.graphics.newFont(fontPath, 48)
        codeFont = love.graphics.newFont(fontPath, 32)
        largeCountFont = love.graphics.newFont(fontPath, 96)  -- Large font for count
        deviceFont = love.graphics.newFont(fontPath, 24)
        -- Logo font for main title
        logoFont = love.graphics.newFont(logoFontPath, 64)
    end)
    if not ok then
        print("ERROR: Failed to load font from " .. fontPath .. ": " .. tostring(err))
        -- Fallback to default fonts
        titleFont = love.graphics.newFont(48)
        codeFont = love.graphics.newFont(32)
        largeCountFont = love.graphics.newFont(96)
        deviceFont = love.graphics.newFont(24)
        logoFont = love.graphics.newFont(64)
    end
    
    -- Create data directory within app folder (with error handling)
    pcall(function()
        os.execute("mkdir -p '" .. DATA_DIR .. "' 2>/dev/null")
    end)
    
    -- Consolidate any existing log files into one
    consolidateLogs()
    
    -- Initialize logging
    logMessage("=== RetroSync App Started ===")
    logMessage("App directory: " .. APP_DIR)
    logMessage("Data directory: " .. DATA_DIR)
    
    -- Override SERVER_URL from config if present
    local configUrl = loadServerUrl()
    if configUrl and configUrl ~= "" then
        SERVER_URL = configUrl
        logMessage("Using server URL from config: " .. SERVER_URL)
    else
        logMessage("Using default server URL: " .. SERVER_URL)
    end
    
    -- Load API key if exists (already paired)
    apiKey = loadApiKey()
    deviceName = loadDeviceName()
    
    if apiKey then
        -- Already paired, go straight to connected state
        currentState = STATE_CONNECTED
        isPaired = true
        homeIntroTimer = 0
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

    -- Advance home intro animation while on CONNECTED screen
    if currentState == STATE_CONNECTED and homeIntroTimer < homeIntroDuration then
        homeIntroTimer = math.min(homeIntroTimer + dt, homeIntroDuration)
    end
    
    -- Clear the "just started" flag after a short delay to allow cancellation
    if uploadJustStarted then
        uploadStartTimer = uploadStartTimer + dt
        if uploadStartTimer >= 0.5 then
            uploadJustStarted = false
            uploadStartTimer = 0
        end
    end
    
    -- Phase 1: Show SYNCING screen immediately (no work this frame)
    if uploadPending then
        uploadPending = false
        uploadDiscoverPending = true
        return
    end

    -- Phase 2: Discover files (one frame); SYNCING already visible
    if uploadDiscoverPending then
        uploadDiscoverPending = false
        doUploadDiscover()
        return
    end

    -- Phase 3: Upload one file per frame so UI updates in real time
    if uploadInProgress then
        doUploadOneFile()
        return
    end

    -- Download: Phase 1 (show screen immediately)
    if downloadPending then
        downloadPending = false
        doDownloadDiscover()
        return
    end

    -- Download: Phase 2 (one file per frame)
    if downloadInProgress then
        doDownloadOneFile()
        return
    end
    
    -- Files list: Defer API call to next frame so screen renders first
    if filesListPending then
        filesListPending = false
        fetchSavesList()
        return
    end
    
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
        love.graphics.setFont(logoFont or titleFont)
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
        -- Connected home screen with animated RETROSYNC header + fading buttons
        local title = "RETROSYNC"

        -- Layout: center the whole block (title + buttons + device name)
        love.graphics.setFont(logoFont or titleFont)
        local titleHeight = (logoFont or titleFont):getHeight()
        love.graphics.setFont(codeFont)
        local lineHeight = codeFont:getHeight()

        -- Vertical spacing: keep the two buttons tightly grouped,
        -- but give more breathing room above (title) and below (device line),
        -- and keep those two gaps symmetrical.
        local gapTitleToButtons = 64
        local gapButtons = 16
        local gapButtonsToDevice = 64

        local optionHeight = 50
        local groupHeight =
            titleHeight +
            gapTitleToButtons +
            optionHeight +
            gapButtons +
            optionHeight +
            gapButtons +
            optionHeight +
            gapButtonsToDevice +
            lineHeight

        local groupTopY = (screenHeight - groupHeight) / 2

        -- Total animation progress 0 -> 1 over homeIntroDuration
        local t = math.max(0, math.min(1, homeIntroTimer / homeIntroDuration))

        -- Per-letter stagger for accordion / tetris effect
        local letterCount = #title
        local fallDuration = 0.35  -- portion of total used for fall + slam
        local stagger = (homeIntroDuration - fallDuration) / math.max(letterCount - 1, 1)

        local targetY = groupTopY
        local totalWidth = titleFont:getWidth(title)
        local startX = (screenWidth - totalWidth) / 2

        love.graphics.setFont(titleFont)
        local x = startX
        for i = 1, letterCount do
            local ch = title:sub(i, i)
            local charWidth = titleFont:getWidth(ch)

            local charStart = (i - 1) * stagger
            local charT = (homeIntroTimer - charStart) / fallDuration

            if charT > 0 then
                if charT > 1 then charT = 1 end
                -- Ease + overshoot for slam, then slight sway
                local eased = charT * charT * (3 - 2 * charT)
                local overshoot = math.sin(eased * math.pi) * 8
                local y = targetY - (1 - eased) * 80 + overshoot

                -- Small horizontal sway based on index
                local sway = math.sin((homeIntroTimer * 10) + i * 0.7) * (1 - charT) * 2

                love.graphics.setColor(1, 1, 1)
                love.graphics.print(ch, x + sway, y)
            end

            x = x + charWidth
        end

        -- Buttons fade in after letters
        local buttonsStart = homeIntroDuration * 0.4
        local buttonsT = 0
        if homeIntroTimer > buttonsStart then
            buttonsT = math.max(0, math.min(1, (homeIntroTimer - buttonsStart) / (homeIntroDuration - buttonsStart)))
        end

        local optionWidth = 260
        local optionX = (screenWidth - optionWidth) / 2

        love.graphics.setFont(codeFont)

        local alpha = buttonsT
        local optionY1 = groupTopY + titleHeight + gapTitleToButtons
        local optionY2 = optionY1 + optionHeight + gapButtons

        -- Option 1: Sync
        if homeSelectedIndex == 1 then
            love.graphics.setColor(0.3, 0.7, 0.9, alpha)
        else
            love.graphics.setColor(0.15, 0.15, 0.25, alpha)
        end
        love.graphics.rectangle("fill", optionX, optionY1, optionWidth, optionHeight, 10, 10)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf("Sync", 0, optionY1 + 10, screenWidth, "center")

        -- Option 2: Recent
        if homeSelectedIndex == 2 then
            love.graphics.setColor(0.3, 0.9, 0.5, alpha)
        else
            love.graphics.setColor(0.15, 0.25, 0.15, alpha)
        end
        love.graphics.rectangle("fill", optionX, optionY2, optionWidth, optionHeight, 10, 10)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf("Recent", 0, optionY2 + 10, screenWidth, "center")

        -- Device line below buttons, lower opacity and smaller font
        if deviceName then
            local deviceY = optionY2 + optionHeight + gapButtonsToDevice
            if deviceFont then
                love.graphics.setFont(deviceFont)
            else
                love.graphics.setFont(codeFont)
            end
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.printf("Device: " .. deviceName, 0, deviceY, screenWidth, "center")
        end
        
    elseif currentState == STATE_SHOWING_FILES then
        -- Recent games list view
        love.graphics.setFont(titleFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("RECENTLY PLAYED", 0, 20, screenWidth, "center")
        
        if filesListLoading then
            love.graphics.setFont(codeFont)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf("Loading...", 0, 120, screenWidth, "center")
        elseif filesListError ~= "" then
            love.graphics.setFont(codeFont)
            love.graphics.setColor(1, 0.3, 0.3)
            love.graphics.printf(filesListError, 0, 120, screenWidth, "center")
        elseif #savesList == 0 then
            love.graphics.setFont(codeFont)
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.printf("No games yet", 0, 120, screenWidth, "center")
        else
            -- Draw scrollable list with selection
            local listStartY = 120
            local lineHeight = 30
            -- Extend list near bottom while keeping a small margin
            local bottomMargin = 20
            local maxVisibleLines = math.floor((screenHeight - listStartY - bottomMargin) / lineHeight)
            local totalLines = #savesList
            
            -- Ensure selected index is valid
            if filesListSelectedIndex < 1 then
                filesListSelectedIndex = 1
            elseif filesListSelectedIndex > totalLines then
                filesListSelectedIndex = totalLines
            end
            
            -- Update scroll position to keep selected item visible
            if filesListSelectedIndex <= filesListScroll then
                filesListScroll = filesListSelectedIndex - 1
            elseif filesListSelectedIndex > filesListScroll + maxVisibleLines then
                filesListScroll = filesListSelectedIndex - maxVisibleLines
            end
            
            -- Calculate visible range
            local startIdx = math.max(1, filesListScroll + 1)
            local endIdx = math.min(totalLines, startIdx + maxVisibleLines - 1)
            
            -- Draw scroll indicator if needed
            if totalLines > maxVisibleLines then
                love.graphics.setFont(codeFont)
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.printf("(" .. startIdx .. "-" .. endIdx .. " / " .. totalLines .. ")", 0, listStartY - 25, screenWidth, "center")
            end
            
            -- Draw visible items
            love.graphics.setFont(codeFont)
            for i = startIdx, endIdx do
                local save = savesList[i]
                local y = listStartY + (i - startIdx) * lineHeight
                local isSelected = (i == filesListSelectedIndex)
                
                -- Draw selection highlight
                if isSelected then
                    love.graphics.setColor(0.2, 0.4, 0.6)
                    love.graphics.rectangle("fill", 10, y - 2, screenWidth - 20, lineHeight - 2, 5, 5)
                end
                
            -- Simplified games list entry:
            --   left  = game name
            --   right = status (SYNCED / DISABLED / NOT ON THIS DEVICE / PENDING)
                local displayName = save.name or "Unknown"
                local statusStr = save.status or ""

                -- Compute available width so name can't overlap the right-aligned status
                local paddingLeft = 20
                local paddingRight = 20
                local gap = 10
                local statusW = statusStr ~= "" and codeFont:getWidth(statusStr) or 0
                local maxNameW = (screenWidth - paddingLeft - paddingRight) - (statusW > 0 and (statusW + gap) or 0)
                displayName = truncateToWidth(displayName, maxNameW, codeFont)
                
                -- Set text color based on selection
                if isSelected then
                    love.graphics.setColor(1, 1, 1)
                else
                    love.graphics.setColor(0.9, 0.9, 0.9)
                end
                love.graphics.printf(displayName, paddingLeft, y, screenWidth - paddingLeft - paddingRight, "left")
                
                -- Show status on the right, color-coded (GREEN / RED / YELLOW)
                if statusStr ~= "" then
                    local statusColor = save.statusColor or {0.8, 0.8, 0.8}
                    love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3])
                    love.graphics.printf(statusStr, paddingLeft, y, screenWidth - paddingLeft - paddingRight, "right")
                end
            end
            
            -- No bottom tooltip; let the list breathe all the way down
        end
        
        
    elseif currentState == STATE_UPLOADING or currentState == STATE_DOWNLOADING or currentState == STATE_SUCCESS then
        -- Unified sync screen: UPLOADED / DOWNLOADED with centered status text
        local leftX = screenWidth * 0.25
        local rightX = screenWidth * 0.75

        -- Measure block to vertically center: counts + labels + status line
        love.graphics.setFont(largeCountFont)
        local countHeight = largeCountFont:getHeight()
        love.graphics.setFont(deviceFont or codeFont)
        local labelHeight = (deviceFont or codeFont):getHeight()
        local statusHeight = codeFont:getHeight()

        local gapCountToLabel = 40
        local gapLabelToStatus = 100

        local blockHeight = countHeight + gapCountToLabel + labelHeight + gapLabelToStatus + statusHeight
        local topY = (screenHeight - blockHeight) / 2

        -- Left side: UPLOADED
        love.graphics.setFont(largeCountFont)
        love.graphics.setColor(0.4, 1, 0.6)
        local upText = tostring(uploadSuccess or 0)
        love.graphics.printf(upText, leftX - 100, topY, 200, "center")
        
        love.graphics.setFont(deviceFont or codeFont)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("UPLOADED", leftX - 100, topY + countHeight + gapCountToLabel, 200, "center")

        -- Right side: DOWNLOADED
        love.graphics.setFont(largeCountFont)
        love.graphics.setColor(0.4, 0.7, 1.0)
        local downText = tostring(downloadSuccess or 0)
        love.graphics.printf(downText, rightX - 100, topY, 200, "center")

        love.graphics.setFont(deviceFont or codeFont)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("DOWNLOADED", rightX - 100, topY + countHeight + gapCountToLabel, 200, "center")

        -- Centered status line under both columns
        local statusText = ""
        local r, g, b = 1, 1, 1

        -- Map states to status label + color
        if currentState == STATE_UPLOADING then
            -- Distinguish initial loading vs active upload
            if uploadPending or uploadDiscoverPending then
                statusText = "LOADING"
                r, g, b = 0.6, 0.6, 0.6      -- gray
            else
                statusText = "UPLOADING"
                r, g, b = 1.0, 0.9, 0.4      -- yellow
            end
        elseif currentState == STATE_DOWNLOADING then
            statusText = "DOWNLOADING"
            r, g, b = 0.5, 0.7, 1.0          -- blue
        elseif currentState == STATE_SUCCESS then
            statusText = "COMPLETE"
            r, g, b = 0.4, 1.0, 0.6          -- green
        end

        love.graphics.setColor(r, g, b)
        love.graphics.setFont(codeFont)
        local statusY = topY + countHeight + gapCountToLabel + labelHeight + gapLabelToStatus
        love.graphics.printf(statusText, 0, statusY, screenWidth, "center")
    end
    
    -- Show error if any (only for non-showing-code states)
    if pairingError ~= "" and currentState ~= STATE_SHOWING_CODE then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.setFont(codeFont)
        love.graphics.printf(pairingError, 0, 460, screenWidth, "center")
    end
end

function love.keypressed(key)
    logMessage("love.keypressed: key=" .. tostring(key) .. ", state=" .. currentState)
    if currentState == STATE_CONNECTED then
        if key == "up" then
            if homeSelectedIndex > 1 then
                homeSelectedIndex = homeSelectedIndex - 1
            end
        elseif key == "down" then
            if homeSelectedIndex < 2 then
                homeSelectedIndex = homeSelectedIndex + 1
            end
        elseif key == "return" or key == "space" or key == "a" or key == "x" then
            -- Confirm current selection
            if homeSelectedIndex == 1 then
                logMessage("love.keypressed: Sync selected from home")
                uploadSaves()
            elseif homeSelectedIndex == 2 then
                logMessage("love.keypressed: Recent selected from home")
                showFilesList()
            end
        elseif key == "escape" then
            logMessage("love.keypressed: Exit triggered via keyboard")
            love.event.quit()
        end
    elseif currentState == STATE_SHOWING_FILES then
        if key == "up" then
            -- Move selection up
            if filesListSelectedIndex > 1 then
                filesListSelectedIndex = filesListSelectedIndex - 1
            end
        elseif key == "down" then
            -- Move selection down
            if filesListSelectedIndex < #savesList then
                filesListSelectedIndex = filesListSelectedIndex + 1
            end
        elseif key == "b" or key == "escape" then
            -- Go back to connected state
            currentState = STATE_CONNECTED
            filesListScroll = 0
            filesListSelectedIndex = 1
        end
    elseif currentState == STATE_UPLOADING or currentState == STATE_DOWNLOADING or currentState == STATE_SUCCESS then
        -- Allow exit during upload or after success
        -- But prevent immediate cancellation right after starting upload
        if (key == "escape" or key == "b") and not uploadJustStarted then
            logMessage("love.keypressed: Exit triggered via keyboard (state=" .. currentState .. ")")
            uploadCancelled = true
            downloadCancelled = true
            currentState = STATE_CONNECTED
        elseif (key == "escape" or key == "b") and uploadJustStarted then
            logMessage("love.keypressed: Cancel ignored (upload just started, state=" .. currentState .. ")")
        end
    end
end

function love.gamepadpressed(joystick, button)
    logMessage("love.gamepadpressed: button=" .. tostring(button) .. ", state=" .. currentState)
    if currentState == STATE_CONNECTED then
        if button == "dpup" then
            if homeSelectedIndex > 1 then
                homeSelectedIndex = homeSelectedIndex - 1
            end
        elseif button == "dpdown" then
            if homeSelectedIndex < 2 then
                homeSelectedIndex = homeSelectedIndex + 1
            end
        elseif button == "a" then
            -- A = confirm current selection
            if homeSelectedIndex == 1 then
                logMessage("love.gamepadpressed: Sync selected from home")
                uploadSaves()
            elseif homeSelectedIndex == 2 then
                logMessage("love.gamepadpressed: Recent selected from home")
                showFilesList()
            end
        end
    elseif currentState == STATE_SHOWING_FILES then
        if button == "dpup" then
            -- Move selection up
            if filesListSelectedIndex > 1 then
                filesListSelectedIndex = filesListSelectedIndex - 1
            end
        elseif button == "dpdown" then
            -- Move selection down
            if filesListSelectedIndex < #savesList then
                filesListSelectedIndex = filesListSelectedIndex + 1
            end
        elseif button == "b" then
            -- B = go back to connected state from files list
            currentState = STATE_CONNECTED
            filesListScroll = 0
            filesListSelectedIndex = 1
        end
    elseif currentState == STATE_UPLOADING or currentState == STATE_DOWNLOADING or currentState == STATE_SUCCESS then
        -- B = go back / cancel on sync screens (A should NOT go back)
        -- Prevent immediate cancellation right after starting upload/download
        if button == "b" and not uploadJustStarted then
            logMessage("love.gamepadpressed: Exit triggered via gamepad (B button, state=" .. currentState .. ")")
            uploadCancelled = true
            downloadCancelled = true
            currentState = STATE_CONNECTED
        elseif button == "b" and uploadJustStarted then
            logMessage("love.gamepadpressed: Cancel ignored (upload just started, state=" .. currentState .. ")")
        end
    end
end

function doUnpairDevice()
    logMessage("doUnpairDevice: Clearing pairing data and returning to code screen")
    apiKey = nil
    deviceName = nil
    deviceCode = nil
    isPaired = false
    pairingError = ""
    homeSelectedIndex = 1
    pcall(function() os.remove(API_KEY_FILE) end)
    pcall(function() os.remove(DEVICE_NAME_FILE) end)
    pcall(function() os.remove(CODE_FILE) end)
    currentState = STATE_SHOWING_CODE
    getCodeFromServer()
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
    logMessage("Request data: {\"deviceType\":\"other\"}")
    
    local url = SERVER_URL .. "/api/devices/code"
    local data = '{"deviceType":"other"}'
    
    local resp = httpPost(url, data)
    
    if resp and resp ~= "" then
        logMessage("Response received: " .. #resp .. " bytes")
        logMessage("Full response: " .. resp)
        
        local result, pos, err = json.decode(resp, 1, nil)
        if err then
            logMessage("JSON decode error: " .. tostring(err) .. " at position " .. tostring(pos))
            result = nil
        end
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
        local result, pos, err = json.decode(resp, 1, nil)
        if err then
            logMessage("JSON decode error: " .. tostring(err) .. " at position " .. tostring(pos))
            result = nil
        end
        
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
local HTTP_GET_TIMEOUT = 30  -- seconds; GETs (saves list, manifest, etc.) can be slower

function httpGet(url, headers)
    local tmpfile = "/tmp/retrosync_resp.txt"
    local headerStr = ""
    if headers then
        for k, v in pairs(headers) do
            headerStr = headerStr .. " -H '" .. k .. ": " .. v .. "'"
        end
    end
    local escapedUrl = url:gsub("'", "'\\''")
    local ok, err = pcall(function()
        os.execute("curl -s -m " .. HTTP_GET_TIMEOUT .. (headerStr ~= "" and " " or "") .. headerStr .. " '" .. escapedUrl .. "' > " .. tmpfile .. " 2>/dev/null")
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
    local tmpfile = DATA_DIR .. "/http_resp.txt"
    local postfile = DATA_DIR .. "/http_post.txt"
    local errfile = DATA_DIR .. "/http_err.txt"
    
    -- Ensure data directory exists
    pcall(function()
        os.execute("mkdir -p '" .. DATA_DIR .. "' 2>/dev/null")
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
    
    -- Determine timeout based on data size (longer for large uploads)
    -- For uploads (large data), use 60 seconds. For other requests, use 10 seconds.
    local dataSize = #data
    local timeout = 10  -- Default timeout
    if dataSize > 100000 then  -- If data is > 100KB, likely an upload
        timeout = 120  -- 2 minutes for large uploads
        logMessage("  Large payload detected (" .. dataSize .. " bytes), using extended timeout: " .. timeout .. "s")
    end
    
    -- Use curl with timeout and better error handling
    -- Escape single quotes in URL if needed
    local escapedUrl = url:gsub("'", "'\\''")
    local exitCodeFile = DATA_DIR .. "/curl_exit.txt"
    -- Capture exit code by appending it to the command
    local cmd = "curl -s -m " .. timeout .. " -X POST " .. headerStr .. " -d @" .. postfile .. " '" .. escapedUrl .. "' > " .. tmpfile .. " 2>" .. errfile .. "; echo $? > " .. exitCodeFile
    logMessage("  Command: curl -s -m " .. timeout .. " -X POST ...")
    
    logMessage("  Executing curl command (timeout: " .. timeout .. "s)...")
    local startTime = os.time()
    local ok, err = pcall(function()
        local result = os.execute(cmd)
        return result
    end)
    local endTime = os.time()
    local elapsed = endTime - startTime
    logMessage("  Curl command completed in " .. elapsed .. " seconds")
    
    if not ok then
        logMessage("ERROR: curl command failed: " .. tostring(err))
        -- Clean up temp files
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' '" .. exitCodeFile .. "' 2>/dev/null") end)
        return nil
    end
    
    -- Check for errors and log to main log file
    local errf = io.open(errfile, "r")
    if errf then
        local errContent = errf:read("*all")
        errf:close()
        if errContent and errContent ~= "" then
            logMessage("curl stderr: " .. errContent)
        end
    end
    
    -- Check if curl timed out (exit code 28) or failed
    local exitCode = 0
    local exitFile = io.open(exitCodeFile, "r")
    if exitFile then
        local exitStr = exitFile:read("*line")
        exitFile:close()
        if exitStr then
            exitCode = tonumber(exitStr) or 0
        end
        pcall(function() os.remove(exitCodeFile) end)
    end
    
    if exitCode ~= 0 then
        if exitCode == 28 then
            logMessage("ERROR: curl timed out after " .. timeout .. " seconds (exit code 28)")
        else
            logMessage("ERROR: curl failed with exit code " .. exitCode)
        end
        -- Clean up temp files
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' 2>/dev/null") end)
        return nil
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
        
        -- Clean up temp files after logging
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' 2>/dev/null") end)
        
        return content
    else
        logMessage("ERROR: Failed to read response file: " .. tmpfile)
        -- Clean up temp files
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' 2>/dev/null") end)
    end
    return nil
end

-- pairDevice function removed - auto-pair endpoint handles everything

function sendHeartbeat()
    if not apiKey then return end
    
    local headers = {["X-API-Key"] = apiKey}
    httpPost(SERVER_URL .. "/api/sync/heartbeat", "{}", headers)
end

-- Fetch saves list from server
function fetchSavesList()
    logMessage("=== fetchSavesList START ===")
    
    if not apiKey then
        logMessage("fetchSavesList: No API key, cannot fetch saves")
        filesListError = "Not authenticated"
        filesListLoading = false
        return
    end
    
    filesListLoading = true
    filesListError = ""
    
    local headers = {["X-API-Key"] = apiKey}
    logMessage("fetchSavesList: Calling httpGet with URL: " .. SERVER_URL .. "/api/saves")
    logMessage("fetchSavesList: API key length: " .. (apiKey and #apiKey or 0))
    local resp = httpGet(SERVER_URL .. "/api/saves", headers)
    
    if resp and resp ~= "" then
        logMessage("fetchSavesList: Response received, length = " .. #resp)
        logMessage("fetchSavesList: Response preview: " .. resp:sub(1, 200))
        local result, pos, err = json.decode(resp, 1, nil)
        if err then
            logMessage("fetchSavesList: JSON decode error: " .. tostring(err) .. " at position " .. tostring(pos))
            filesListError = "Invalid response"
            filesListLoading = false
            return
        end
        
        if result then
            logMessage("fetchSavesList: JSON decoded successfully")
            logMessage("fetchSavesList: result.success = " .. tostring(result.success))
            logMessage("fetchSavesList: result.data exists = " .. tostring(result.data ~= nil))
            if result.data then
                logMessage("fetchSavesList: result.data.saves exists = " .. tostring(result.data.saves ~= nil))
            end
        end
        
        if result and result.success and result.data then
            local rawSaves = result.data.saves or {}
            logMessage("fetchSavesList: Successfully fetched " .. #rawSaves .. " saves (raw)")

            ----------------------------------------------------------------
            -- Determine current device and per-game status (including pending)
            ----------------------------------------------------------------
            local currentDeviceId = nil
            local manifestBySaveId = {}

            -- Try to fetch manifest to learn which saves are mapped/synced
            logMessage("fetchSavesList: Fetching manifest to determine device + per-game status")
            local manifestResp = httpGet(SERVER_URL .. "/api/sync/manifest", headers)
            if manifestResp and manifestResp ~= "" then
                logMessage("fetchSavesList: Manifest response length = " .. #manifestResp)
                local manResult, manPos, manErr = json.decode(manifestResp, 1, nil)
                if manErr then
                    logMessage("fetchSavesList: Manifest JSON decode error: " .. tostring(manErr) .. " at position " .. tostring(manPos))
                elseif manResult and manResult.success and manResult.data then
                    currentDeviceId = manResult.data.device and manResult.data.device.id or nil
                    logMessage("fetchSavesList: Current device id from manifest = " .. tostring(currentDeviceId))
                    local manifest = manResult.data.manifest or {}
                    for _, item in ipairs(manifest) do
                        if item and item.saveId then
                            manifestBySaveId[item.saveId] = item
                        end
                    end
                    logMessage("fetchSavesList: Manifest entries mapped for " .. tostring(#manifest) .. " saves")
                else
                    logMessage("fetchSavesList: Manifest API returned error or invalid structure")
                end
            else
                logMessage("fetchSavesList: No manifest response (resp is nil or empty)")
            end

            ----------------------------------------------------------------
            -- Build simplified games list for UI
            ----------------------------------------------------------------
            savesList = {}

            -- Status colors
            local GREEN = {0.2, 0.9, 0.3}
            local RED = {0.95, 0.25, 0.25}
            local YELLOW = {0.95, 0.85, 0.25}
            local BLUE = {0.4, 0.6, 1.0}

            for _, save in ipairs(rawSaves) do
                -- Name: prefer displayName, then saveKey
                local name = save.displayName or save.saveKey or "Unknown"

                -- Collect where this game is synced (any device with syncEnabled = true)
                local syncedDevices = {}
                if save.locations then
                    for _, loc in ipairs(save.locations) do
                        if loc.syncEnabled then
                            local dname = loc.deviceName or loc.deviceType or "Device"
                            table.insert(syncedDevices, dname)
                        end
                    end
                end

                local syncedOnSummary = nil
                if #syncedDevices > 0 then
                    -- Deduplicate device names a bit
                    local seenNames = {}
                    local unique = {}
                    for _, dname in ipairs(syncedDevices) do
                        if not seenNames[dname] then
                            seenNames[dname] = true
                            table.insert(unique, dname)
                        end
                    end
                    syncedOnSummary = table.concat(unique, ", ")
                end

                -- Default status: NOT ON THIS DEVICE
                local status = "NOT ON THIS DEVICE"
                local statusColor = YELLOW
                local pendingDir = nil  -- "UP" or "DOWN"
                local deviceLocalPath = nil

                if currentDeviceId and save.locations then
                    for _, loc in ipairs(save.locations) do
                        if loc.deviceId == currentDeviceId then
                            deviceLocalPath = loc.localPath
                            if loc.syncEnabled then
                                status = "SYNCED"
                                statusColor = GREEN
                            else
                                status = "DISABLED"
                                statusColor = RED
                            end
                            break
                        end
                    end
                end

                -- Compute pending direction for this device, based on manifest vs local mtime.
                -- Be defensive: only call getFileMtimeSeconds if it exists.
                if currentDeviceId and save.id and deviceLocalPath then
                    local manItem = manifestBySaveId[save.id]
                    local latest = manItem and manItem.latestVersion or nil
                    local cloudMs = latest and tonumber(latest.localModifiedAtMs or latest.uploadedAtMs) or nil

                    local localMtime = nil
                    if getFileMtimeSeconds then
                        localMtime = getFileMtimeSeconds(deviceLocalPath)
                    end
                    local localMs = localMtime and (localMtime * 1000) or nil

                    -- Allow a generous tolerance window between local and cloud mtimes.
                    -- Many devices have coarse filesystem timestamps and/or clock skew,
                    -- so we only treat something as truly "pending" when the difference
                    -- is clearly significant.
                    local MTIME_TOLERANCE_MS = 10 * 60 * 1000 -- 10 minutes

                    if localMs and cloudMs then
                        if localMs > cloudMs + MTIME_TOLERANCE_MS then
                            pendingDir = "UP"
                        elseif cloudMs > localMs + MTIME_TOLERANCE_MS then
                            pendingDir = "DOWN"
                        end
                    elseif localMs and not cloudMs then
                        -- Has local file but no known cloud version for this device yet
                        pendingDir = "UP"
                    end
                    -- IMPORTANT: we do NOT treat (cloudMs and not localMs) as "PENDING DOWN".
                    -- In practice, getFileMtimeSeconds can fail for reasons other than a
                    -- missing file (e.g., platform quirks), and that was causing almost
                    -- everything to show as PENDING ↓ even when it was actually synced.
                end

                -- Fallback: if no explicit mapping for this device but manifest
                -- says this save is present, treat it as SYNCED (no pending info).
                if currentDeviceId and status == "NOT ON THIS DEVICE" and save.id and manifestBySaveId[save.id] then
                    status = "SYNCED"
                    statusColor = GREEN
                end

                -- If pending in either direction, override status label + color
                if pendingDir == "UP" then
                    status = "PENDING ↑ (UP)"
                    statusColor = BLUE
                elseif pendingDir == "DOWN" then
                    status = "PENDING ↓ (DOWN)"
                    statusColor = BLUE
                end

                table.insert(savesList, {
                    name = name,
                    status = status,
                    statusColor = statusColor,
                    syncedOn = syncedOnSummary,
                })
            end

            logMessage("fetchSavesList: Built games list with " .. #savesList .. " entries")
            filesListError = ""
        else
            logMessage("fetchSavesList: API returned error or invalid structure")
            if result then
                logMessage("fetchSavesList: Error message: " .. tostring(result.message or result.error or "No message"))
            end
            filesListError = result and (result.message or result.error or "Failed to fetch saves") or "Unknown error"
            savesList = {}
        end
    else
        logMessage("fetchSavesList: No response from server (resp is nil or empty)")
        filesListError = "Connection failed"
        savesList = {}
    end
    
    filesListLoading = false
    logMessage("=== fetchSavesList END ===")
end

-- Show recent games list (called when RECENT is selected)
function showFilesList()
    logMessage("=== showFilesList CALLED ===")
    filesListScroll = 0
    filesListSelectedIndex = 1
    savesList = {}
    filesListError = ""
    filesListLoading = true  -- Show loading state immediately
    currentState = STATE_SHOWING_FILES  -- Show screen immediately
    filesListPending = true  -- Defer API call to next frame so screen renders first
end

-- Format file size for display
function formatFileSize(bytes)
    if not bytes or bytes == 0 then
        return "0 B"
    end
    
    local kb = bytes / 1024
    if kb < 1 then
        return bytes .. " B"
    end
    
    local mb = kb / 1024
    if mb < 1 then
        return string.format("%.1f KB", kb)
    end
    
    local gb = mb / 1024
    if gb < 1 then
        return string.format("%.1f MB", mb)
    end
    
    return string.format("%.2f GB", gb)
end

-- Truncate text to fit within pixel width (adds "..." when needed)
function truncateToWidth(text, maxWidth, font)
    if not text then return "" end
    if not font or maxWidth <= 0 then return "..." end

    if font:getWidth(text) <= maxWidth then
        return text
    end

    local ellipsis = "..."
    local ellipsisW = font:getWidth(ellipsis)
    if ellipsisW >= maxWidth then
        return ellipsis
    end

    -- Binary search best cut length (fast even for long strings)
    local lo, hi = 0, #text
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        local candidate = text:sub(1, mid) .. ellipsis
        if font:getWidth(candidate) <= maxWidth then
            lo = mid
        else
            hi = mid - 1
        end
    end

    return text:sub(1, lo) .. ellipsis
end

function uploadSaves()
    logMessage("=== uploadSaves CALLED ===")
    
    if not apiKey then
        logMessage("uploadSaves: No API key, cannot upload")
        currentState = STATE_SHOWING_CODE
        return
    end
    
    logMessage("uploadSaves: API key exists, length: " .. (apiKey and #apiKey or 0))
    
    -- New sync session: clear session flags and download counters
    syncSessionHadUpload = false
    syncSessionHadDownload = false
    downloadSuccess = 0
    downloadTotal = 0
    downloadCancelled = false
    downloadQueue = {}
    downloadNextIndex = 1
    downloadFailedFiles = {}
    
    -- Immediately set state to UPLOADING and reset counters
    -- This allows the SYNCING screen to show before any work (find + upload) runs
    currentState = STATE_UPLOADING
    uploadSuccess = 0
    uploadTotal = 0
    uploadCancelled = false
    uploadProgress = ""
    pairingError = ""  -- Clear any previous errors
    uploadPending = true  -- First frame: just show SYNCING, no work
    uploadDiscoverPending = false
    uploadInProgress = false
    uploadQueue = {}
    uploadNextIndex = 1
    uploadFailedFiles = {}
    uploadJustStarted = true  -- Prevent immediate cancellation
    uploadStartTimer = 0  -- Reset timer
    logMessage("uploadSaves: State immediately set to UPLOADING, work deferred (chunked per frame)")
end

-- Get file modified time (seconds since epoch) using shell
-- Tries multiple methods for compatibility with different stat implementations
local function getFileMtimeSeconds(path)
    if not path or path == "" then
        logMessage("getFileMtimeSeconds: Invalid path (nil or empty)")
        return nil
    end
    local escaped = path:gsub("'", "'\\''")
    
    -- Try method 1: stat -c %Y (GNU stat)
    local cmd1 = "stat -c %Y '" .. escaped .. "' 2>/dev/null"
    logMessage("getFileMtimeSeconds: Trying method 1 (GNU stat): " .. cmd1)
    local h1 = io.popen(cmd1)
    if h1 then
        local out1 = h1:read("*all") or ""
        pcall(function() h1:close() end)
        out1 = out1:match("^%s*(.-)%s*$")
        local mtime1 = tonumber(out1)
        if mtime1 then
            logMessage("getFileMtimeSeconds: Success with method 1 - mtime = " .. mtime1 .. " seconds")
            return mtime1
        end
        logMessage("getFileMtimeSeconds: Method 1 failed, output: '" .. tostring(out1) .. "'")
    end
    
    -- Try method 2: stat -t (POSIX stat, returns timestamp as last field)
    local cmd2 = "stat -t '" .. escaped .. "' 2>/dev/null"
    logMessage("getFileMtimeSeconds: Trying method 2 (POSIX stat): " .. cmd2)
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
                logMessage("getFileMtimeSeconds: Success with method 2 - mtime = " .. mtime2 .. " seconds")
                return mtime2
            end
        end
        logMessage("getFileMtimeSeconds: Method 2 failed, output: '" .. tostring(out2) .. "'")
    end
    
    -- Try method 3: ls -l and parse (works on most systems)
    local cmd3 = "ls -l '" .. escaped .. "' 2>/dev/null"
    logMessage("getFileMtimeSeconds: Trying method 3 (ls -l): " .. cmd3)
    local h3 = io.popen(cmd3)
    if h3 then
        local out3 = h3:read("*all") or ""
        pcall(function() h3:close() end)
        -- ls -l format: -rw-r--r-- 1 user group size MMM DD HH:MM filename (recent)
        --              -rw-r--r-- 1 user group size MMM DD YYYY filename (old)
        -- Parse: skip first 5 fields (perms, links, user, group, size), then date
        local monthStr, dayStr, timeOrYear = out3:match("%S+%s+%d+%s+%S+%s+%S+%s+%d+%s+(%w+)%s+(%d+)%s+(%S+)")
        if monthStr and dayStr and timeOrYear then
            logMessage("getFileMtimeSeconds: Method 3 parsed: month=" .. monthStr .. ", day=" .. dayStr .. ", timeOrYear=" .. timeOrYear)
            
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
                        logMessage("getFileMtimeSeconds: File date appears to be last year (month=" .. month .. " > current=" .. currentMonth .. ")")
                    end
                    
                    logMessage("getFileMtimeSeconds: Parsed as recent file: " .. year .. "-" .. month .. "-" .. day .. " " .. hour .. ":" .. min)
                else
                    -- Old file: YYYY format
                    year = tonumber(timeOrYear)
                    hour = 0
                    min = 0
                    logMessage("getFileMtimeSeconds: Parsed as old file: " .. year .. "-" .. month .. "-" .. day)
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
                        logMessage("getFileMtimeSeconds: Success with method 3 - mtime = " .. mtime3 .. " seconds (" .. os.date("%Y-%m-%d %H:%M:%S", mtime3) .. ")")
                        return mtime3
                    else
                        logMessage("getFileMtimeSeconds: os.time() failed for parsed date")
                    end
                end
            else
                logMessage("getFileMtimeSeconds: Failed to parse month/day from: " .. monthStr .. " " .. dayStr)
            end
        else
            logMessage("getFileMtimeSeconds: Method 3 failed to match date pattern, output: '" .. tostring(out3) .. "'")
        end
    end
    
    -- Try method 4: BusyBox stat format (stat file | grep Modify, then convert with date)
    local cmd4 = "stat '" .. escaped .. "' 2>/dev/null | grep -i modify"
    logMessage("getFileMtimeSeconds: Trying method 4 (BusyBox stat | grep): " .. cmd4)
    local h4 = io.popen(cmd4)
    if h4 then
        local out4 = h4:read("*all") or ""
        pcall(function() h4:close() end)
        -- Parse "Modify: 2026-01-28 17:05:19.123456789 +0000" or "Modify: 2026-01-28 17:05:19"
        local dateStr = out4:match("Modify:%s+(%S+%s+%S+)")
        if dateStr then
            logMessage("getFileMtimeSeconds: Method 4 found date string: " .. tostring(dateStr))
            -- Try to convert using date command (GNU date format)
            local cmd4b = "date -d '" .. dateStr .. "' +%s 2>/dev/null"
            logMessage("getFileMtimeSeconds: Trying date conversion (GNU): " .. cmd4b)
            local h4b = io.popen(cmd4b)
            if h4b then
                local out4b = h4b:read("*all") or ""
                pcall(function() h4b:close() end)
                out4b = out4b:match("^%s*(.-)%s*$")
                local mtime4 = tonumber(out4b)
                if mtime4 and mtime4 > 0 then
                    logMessage("getFileMtimeSeconds: Success with method 4 - mtime = " .. mtime4 .. " seconds")
                    return mtime4
                end
            end
            -- Try BusyBox date format
            local cmd4c = "date -D '%Y-%m-%d %H:%M:%S' -d '" .. dateStr .. "' +%s 2>/dev/null"
            logMessage("getFileMtimeSeconds: Trying date conversion (BusyBox): " .. cmd4c)
            local h4c = io.popen(cmd4c)
            if h4c then
                local out4c = h4c:read("*all") or ""
                pcall(function() h4c:close() end)
                out4c = out4c:match("^%s*(.-)%s*$")
                local mtime4c = tonumber(out4c)
                if mtime4c and mtime4c > 0 then
                    logMessage("getFileMtimeSeconds: Success with method 4 (BusyBox date) - mtime = " .. mtime4c .. " seconds")
                    return mtime4c
                end
            end
        end
        logMessage("getFileMtimeSeconds: Method 4 failed, output: '" .. tostring(out4) .. "'")
    end
    
    logMessage("getFileMtimeSeconds: All methods failed for path: " .. tostring(path))
    return nil
end

-- Set file modified time (seconds since epoch). Preserves mtime when syncing so
-- "last modified" does not change when only uploading or downloading.
local function setFileMtimeSeconds(path, sec)
    if not path or path == "" or not sec or sec <= 0 then return false end
    local escaped = path:gsub("'", "'\\''")
    -- touch -d @SEC path (POSIX/GNU)
    local cmd = "touch -d '@" .. tostring(math.floor(sec)) .. "' '" .. escaped .. "' 2>/dev/null"
    local ok = os.execute(cmd)
    if ok == 0 then
        logMessage("setFileMtimeSeconds: Set mtime for " .. tostring(path) .. " to " .. tostring(sec))
        return true
    end
    logMessage("setFileMtimeSeconds: Failed to set mtime for " .. tostring(path))
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

-- Fetch per-device manifest from server
local function fetchManifest()
    if not apiKey then return nil, "Not authenticated" end
    local headers = {["X-API-Key"] = apiKey}
    local resp = httpGet(SERVER_URL .. "/api/sync/manifest", headers)
    if not resp or resp == "" then return nil, "No response" end
    local result, pos, err = json.decode(resp, 1, nil)
    if err then return nil, "Invalid manifest JSON" end
    if not (result and result.success and result.data and result.data.manifest) then
        return nil, (result and (result.message or result.error) or "Manifest error")
    end
    return result.data.manifest, nil
end

local function downloadOne(saveVersionId, outPath, mtimeSec)
    if not apiKey then return false, "No API key" end
    if not saveVersionId or saveVersionId == "" then return false, "Missing saveVersionId" end
    if not outPath or outPath == "" then return false, "Missing output path" end

    ensureParentDir(outPath)

    -- Create backup if target file exists
    local escapedOutPath = outPath:gsub("'", "'\\''")
    local fileExists = os.execute("test -f '" .. escapedOutPath .. "' 2>/dev/null")
    if fileExists == 0 then
        local bakPath = outPath .. ".bak"
        local escapedBakPath = bakPath:gsub("'", "'\\''")
        logMessage("download: Creating backup: " .. tostring(bakPath))
        os.execute("cp '" .. escapedOutPath .. "' '" .. escapedBakPath .. "' 2>/dev/null")
    end

    local tmpfile = DATA_DIR .. "/tmp_download_" .. os.time() .. "_" .. math.random(10000) .. ".bin"
    tmpfile = tmpfile:gsub("[^%w/%.%-_]", "_")

    local url = SERVER_URL .. "/api/sync/download?saveVersionId=" .. tostring(saveVersionId)
    local cmd = "curl -sS -L -H \"X-API-Key: " .. tostring(apiKey) .. "\" \"" .. url .. "\" -o \"" .. tmpfile .. "\""
    local exitCode = os.execute(cmd)
    if exitCode ~= 0 then
        pcall(function() os.execute("rm -f \"" .. tmpfile .. "\" 2>/dev/null") end)
        return false, "curl failed"
    end

    local mvCmd = "mv \"" .. tmpfile .. "\" \"" .. outPath .. "\" 2>/dev/null"
    local mvExit = os.execute(mvCmd)
    if mvExit ~= 0 then
        pcall(function() os.execute("rm -f \"" .. tmpfile .. "\" 2>/dev/null") end)
        return false, "failed to write file"
    end
    -- Preserve cloud's original mtime so file "last modified" does not change when only downloading
    if mtimeSec and mtimeSec > 0 then
        setFileMtimeSeconds(outPath, mtimeSec)
    end
    return true, nil
end

function downloadSaves(fromUpload)
    logMessage("=== downloadSaves CALLED (fromUpload=" .. tostring(fromUpload) .. ") ===")
    if not apiKey then
        currentState = STATE_SHOWING_CODE
        return
    end
    
    -- If this is a standalone download (user hit DOWNLOAD directly),
    -- treat it as a new sync session from the perspective of the summary.
    if not fromUpload then
        syncSessionHadUpload = false
        uploadSuccess = 0
        uploadTotal = 0
    end
    syncSessionHadDownload = false
    
    currentState = STATE_DOWNLOADING
    downloadSuccess = 0
    downloadTotal = 0
    downloadCancelled = false
    downloadProgress = ""
    pairingError = ""
    downloadPending = true -- next frame: fetch manifest and build queue
    downloadInProgress = false
    downloadQueue = {}
    downloadNextIndex = 1
    downloadFailedFiles = {}
    uploadJustStarted = true -- reuse existing cooldown to prevent immediate cancel
    uploadStartTimer = 0
end

function doDownloadDiscover()
    logMessage("=== doDownloadDiscover START ===")
    local ok, err = pcall(function()
        local manifest, manErr = fetchManifest()
        if not manifest then
            pairingError = "Manifest error: " .. tostring(manErr or "unknown")
            currentState = STATE_CONNECTED
            return
        end

        downloadQueue = {}
        for _, item in ipairs(manifest) do
            if item and item.localPath and item.latestVersion and item.latestVersion.id then
                -- Normalize certain special-case subdirectories for target paths.
                local targetPath = item.localPath
                if targetPath:match("/%.netplay/") then
                    local normalized = targetPath:gsub("/%.netplay/", "/")
                    logMessage("download: Normalizing netplay path " .. tostring(targetPath) .. " -> " .. tostring(normalized))
                    targetPath = normalized
                end

                local cloudMs = item.latestVersion.localModifiedAtMs or item.latestVersion.uploadedAtMs or 0
                -- Only queue files that need download: local missing or local older than cloud
                local localMtime = getFileMtimeSeconds(targetPath)
                local localMs = localMtime and (localMtime * 1000) or nil
                local needDownload = true
                if localMs and cloudMs and cloudMs > 0 and cloudMs <= localMs then
                    needDownload = false
                    logMessage("download: SKIP (local newer or equal) " .. tostring(targetPath) .. " - not queuing")
                end
                if needDownload then
                    table.insert(downloadQueue, {
                        localPath = targetPath,
                        saveVersionId = item.latestVersion.id,
                        cloudMs = cloudMs,
                        displayName = item.displayName or item.localPath
                    })
                end
            end
        end

        downloadTotal = #downloadQueue
        downloadSuccess = 0
        downloadNextIndex = 1
        downloadFailedFiles = {}

        if downloadTotal == 0 then
            -- No downloads needed (everything already up to date or no mapped saves yet).
            -- Treat this as a successful, no-op sync instead of an error.
            syncSessionHadDownload = false
            downloadSuccess = 0
            pairingError = ""
            currentState = STATE_SUCCESS
            return
        end

        downloadInProgress = true
    end)

    if not ok then
        logMessage("CRASH in doDownloadDiscover: " .. tostring(err))
        pairingError = "Download error: " .. tostring(err)
        currentState = STATE_CONNECTED
    end
    logMessage("=== doDownloadDiscover END ===")
end

function doDownloadOneFile()
    if downloadCancelled then
        downloadInProgress = false
        currentState = STATE_CONNECTED
        return
    end

    if downloadNextIndex > downloadTotal then
        downloadInProgress = false
        -- Mark that this sync session performed downloads
        syncSessionHadDownload = (downloadSuccess > 0)
        currentState = STATE_SUCCESS
        return
    end

    local i = downloadNextIndex
    local item = downloadQueue[i]
    if not item or not item.localPath or not item.saveVersionId then
        table.insert(downloadFailedFiles, {index = i, path = "INVALID", reason = "Missing fields"})
        downloadNextIndex = downloadNextIndex + 1
        return
    end

    -- Queue was built with only items that need download; no skip check needed here
    local cloudMs = tonumber(item.cloudMs) or 0
    local mtimeSec = (cloudMs and cloudMs > 0) and (cloudMs / 1000) or nil

    logMessage("download: GET " .. tostring(item.displayName) .. " -> " .. tostring(item.localPath))
    local ok, reason = downloadOne(item.saveVersionId, item.localPath, mtimeSec)
    if ok then
        downloadSuccess = downloadSuccess + 1
    else
        table.insert(downloadFailedFiles, {index = i, path = item.localPath, reason = reason or "failed"})
    end

    downloadNextIndex = downloadNextIndex + 1
end

-- Normalize path for matching manifest (same as server: .netplay -> canonical)
local function normalizePathForMatch(path)
    if not path or path == "" then return path end
    return path:gsub("/%.netplay/", "/")
end

function doUploadDiscover()
    logMessage("=== doUploadDiscover START ===")
    local ok, err = pcall(function()
        logMessage("uploadSaves: Calling findSaveFiles()")
        local findOk, findResult = pcall(function() return findSaveFiles() end)
        if not findOk then
            logMessage("CRASH in findSaveFiles: " .. tostring(findResult))
            error("findSaveFiles crashed: " .. tostring(findResult))
        end
        local saveFiles = findResult
        if not saveFiles then
            logMessage("uploadSaves: findSaveFiles returned nil")
            uploadProgress = "Error finding save files"
            uploadJustStarted = false
            uploadStartTimer = 0
            currentState = STATE_CONNECTED
            return
        end
        logMessage("uploadSaves: Found " .. #saveFiles .. " save files")
        for idx, fpath in ipairs(saveFiles) do
            logMessage("uploadSaves: File " .. idx .. ": " .. tostring(fpath))
        end
        if #saveFiles == 0 then
            logMessage("uploadSaves: No save files found, returning to CONNECTED state")
            uploadProgress = "No save files found"
            uploadJustStarted = false
            uploadStartTimer = 0
            currentState = STATE_CONNECTED
            return
        end

        -- Build cloud map from manifest: only upload files not already on cloud (same path + same/newer mtime)
        -- Also build a secondary map by saveKey (filename) for cross-emulator duplicate detection
        local cloudByPath = {}
        local cloudBySaveKey = {}  -- maps filename -> {cloudMs, byteSize, contentHash}
        local manifest, manErr = fetchManifest()
        if manifest then
            for _, item in ipairs(manifest) do
                if item and item.localPath and item.latestVersion then
                    local cloudMs = item.latestVersion.localModifiedAtMs or item.latestVersion.uploadedAtMs or 0
                    local byteSize = item.latestVersion.byteSize or 0
                    local contentHash = item.latestVersion.contentHash or ""
                    
                    -- Map by full path
                    local key = item.localPath
                    if not cloudByPath[key] or (cloudMs and cloudMs > (cloudByPath[key].cloudMs or 0)) then
                        cloudByPath[key] = {cloudMs = cloudMs, byteSize = byteSize, contentHash = contentHash}
                    end
                    local norm = normalizePathForMatch(item.localPath)
                    if norm ~= key then
                        if not cloudByPath[norm] or (cloudMs and cloudMs > (cloudByPath[norm].cloudMs or 0)) then
                            cloudByPath[norm] = {cloudMs = cloudMs, byteSize = byteSize, contentHash = contentHash}
                        end
                    end
                    
                    -- Map by saveKey (filename) for cross-emulator detection
                    local saveKey = item.saveKey
                    if saveKey and saveKey ~= "" then
                        if not cloudBySaveKey[saveKey] or (cloudMs and cloudMs > (cloudBySaveKey[saveKey].cloudMs or 0)) then
                            cloudBySaveKey[saveKey] = {cloudMs = cloudMs, byteSize = byteSize, contentHash = contentHash}
                        end
                    end
                end
            end
        else
            logMessage("uploadSaves: No manifest (will upload all): " .. tostring(manErr or "unknown"))
        end

        -- Helper to get local file size
        local function getFileSize(path)
            local f = io.open(path, "rb")
            if not f then return nil end
            local size = f:seek("end")
            f:close()
            return size
        end

        uploadQueue = {}
        -- 65 seconds tolerance: ls -l only gives minute precision, so we need buffer for rounding
        local MTIME_TOLERANCE_MS = 65000
        for i = 1, #saveFiles do
            local fpath = saveFiles[i]
            local normPath = normalizePathForMatch(fpath)
            local cloudEntry = cloudByPath[fpath] or cloudByPath[normPath]
            local filename = fpath:match("[^/]+$")
            local saveKeyEntry = cloudBySaveKey[filename]
            local localMtime = getFileMtimeSeconds(fpath)
            local localMs = localMtime and (localMtime * 1000) or nil
            local needUpload = true
            local skipReason = nil
            
            -- First check: match by full path (path is in manifest)
            if needUpload and cloudEntry and cloudEntry.cloudMs and cloudEntry.cloudMs > 0 and localMs then
                if localMs <= cloudEntry.cloudMs + MTIME_TOLERANCE_MS then
                    needUpload = false
                    skipReason = "already on cloud (path match)"
                end
            end
            
            -- Second check: if not skipped by path, try matching by filename + size
            -- This catches files from different emulator folders with identical content.
            -- Do NOT skip if local mtime is clearly newer than cloud (user likely modified the file).
            -- Also do not skip by filename+size when we have no local mtime (can't prove not newer).
            if needUpload and saveKeyEntry and saveKeyEntry.byteSize and saveKeyEntry.byteSize > 0 and localMs then
                local localSize = getFileSize(fpath)
                if localSize and localSize == saveKeyEntry.byteSize then
                    local cloudMs = saveKeyEntry.cloudMs or 0
                    if cloudMs > 0 and localMs > cloudMs + MTIME_TOLERANCE_MS then
                        -- Local clearly newer: likely modified, do not skip
                    else
                        -- Same filename+size and not clearly newer
                        needUpload = false
                        skipReason = "already on cloud (same filename+size from different emulator)"
                    end
                end
            end
            
            if not needUpload then
                logMessage("uploadSaves: SKIP (" .. (skipReason or "unknown") .. ") " .. tostring(fpath))
            else
                table.insert(uploadQueue, fpath)
            end
        end
        uploadTotal = #uploadQueue
        uploadSuccess = 0
        uploadNextIndex = 1
        uploadFailedFiles = {}
        uploadInProgress = (#uploadQueue > 0)
        logMessage("uploadSaves: Will upload " .. uploadTotal .. " files (of " .. #saveFiles .. " discovered)")
        if uploadTotal == 0 then
            uploadProgress = "All files already synced"
            uploadJustStarted = false
            uploadStartTimer = 0
            -- Still run download phase after "upload" (nothing to upload)
            logMessage("uploadSaves: Starting download phase (no uploads needed)")
            downloadSaves(true)
            return
        end
    end)
    if not ok then
        logMessage("CRASH in doUploadDiscover: " .. tostring(err))
        logMessage("CRASH stack trace: " .. debug.traceback())
        pairingError = "Upload error: " .. tostring(err)
        uploadJustStarted = false
        uploadStartTimer = 0
        currentState = STATE_CONNECTED
    end
    logMessage("=== doUploadDiscover END ===")
end

function doUploadOneFile()
    logMessage("=== doUploadOneFile (index " .. tostring(uploadNextIndex) .. ") ===")
    if uploadCancelled then
        logMessage("uploadSaves: Upload cancelled by user, stopping")
        uploadInProgress = false
        uploadJustStarted = false
        uploadStartTimer = 0
        if #uploadFailedFiles > 0 then
            logMessage("uploadSaves: FAILED FILES SUMMARY:")
            for _, fail in ipairs(uploadFailedFiles) do
                logMessage("uploadSaves:   File " .. fail.index .. ": " .. fail.path .. " - " .. fail.reason)
            end
        end
        currentState = STATE_CONNECTED
        return
    end
    if uploadNextIndex > uploadTotal then
        logMessage("uploadSaves: All files processed")
        uploadInProgress = false
        uploadJustStarted = false
        uploadStartTimer = 0
        if #uploadFailedFiles > 0 then
            logMessage("uploadSaves: FAILED FILES SUMMARY:")
            for _, fail in ipairs(uploadFailedFiles) do
                logMessage("uploadSaves:   File " .. fail.index .. ": " .. fail.path .. " - " .. fail.reason)
            end
        else
            logMessage("uploadSaves: All files uploaded successfully!")
        end
        logMessage("uploadSaves: Complete - " .. uploadSuccess .. "/" .. uploadTotal .. " files uploaded")
        
        -- Mark that this sync session performed uploads
        syncSessionHadUpload = (uploadSuccess > 0)

        -- After uploads finish, automatically run download phase (combined sync)
        logMessage("uploadSaves: Starting download phase after uploads complete")
        downloadSaves(true)
        return
    end
    local i = uploadNextIndex
    local filepath = uploadQueue[i]
    if not filepath or filepath == "" then
        logMessage("uploadSaves: Skipping invalid filepath at index " .. i)
        table.insert(uploadFailedFiles, {index = i, path = "INVALID", reason = "Empty or nil filepath"})
        uploadNextIndex = uploadNextIndex + 1
        return
    end
    logMessage("uploadSaves: Uploading file " .. i .. "/" .. uploadTotal .. ": " .. tostring(filepath))
    local uploadOk, uploadResult = pcall(function() return uploadSave(filepath) end)
    if uploadOk and uploadResult == true then
        uploadSuccess = uploadSuccess + 1
        logMessage("uploadSaves: Successfully uploaded file " .. i .. " (" .. uploadSuccess .. "/" .. uploadTotal .. ")")
    elseif uploadOk and uploadResult == "skipped" then
        logMessage("uploadSaves: Skipped (sync disabled) file " .. i .. " - not counting as fail or success")
        -- Don't add to failed; don't increment success (only actual uploads count in report)
    elseif not uploadOk then
        logMessage("uploadSaves: CRASH uploading file " .. i .. ": " .. tostring(uploadResult))
        table.insert(uploadFailedFiles, {index = i, path = filepath, reason = "CRASH: " .. tostring(uploadResult)})
    else
        logMessage("uploadSaves: Upload failed for file " .. i .. ": " .. tostring(uploadResult))
        table.insert(uploadFailedFiles, {index = i, path = filepath, reason = "Failed: " .. tostring(uploadResult)})
    end
    uploadNextIndex = uploadNextIndex + 1
end

function uploadSave(filepath)
    logMessage("=== uploadSave START ===")
    logMessage("uploadSave: filepath = " .. tostring(filepath))
    
    if not apiKey then 
        logMessage("uploadSave: No API key, returning false")
        return false 
    end
    logMessage("uploadSave: API key exists")
    
    -- Validate filepath
    if not filepath or filepath == "" then
        logMessage("uploadSave: Invalid filepath")
        return false
    end
    
    logMessage("uploadSave: Extracting filename from path")
    local filename = filepath:match("/([^/]+)$") or filepath
    logMessage("uploadSave: filename = " .. tostring(filename))
    
    local fileSize = 0
    local fileContent = nil
    
    logMessage("uploadSave: Starting file read operation")
    -- Read file content and get file size with error handling
    local ok, err = pcall(function()
        logMessage("uploadSave: Inside pcall for file read")
        logMessage("uploadSave: Opening file: " .. tostring(filepath))
        -- Escape filepath for safety (though io.open should handle it)
        local f = io.open(filepath, "rb")  -- Open in binary mode
        if not f then
            logMessage("uploadSave: io.open returned nil for: " .. tostring(filepath))
            error("Failed to open file: " .. tostring(filepath))
        end
        logMessage("uploadSave: File opened successfully")
        
        -- Get file size
        logMessage("uploadSave: Seeking to end to get file size")
        f:seek("end")
        fileSize = f:seek()
        logMessage("uploadSave: File size = " .. tostring(fileSize) .. " bytes")
        
        if fileSize == 0 then
            logMessage("uploadSave: File is empty, closing and erroring")
            f:close()
            error("File is empty")
        end
        
        -- Seek back to start
        logMessage("uploadSave: Seeking back to start")
        f:seek("set", 0)
        
        -- Read file content
        logMessage("uploadSave: Reading file content (this may take a moment for large files)")
        fileContent = f:read("*all")
        logMessage("uploadSave: File read complete, content length = " .. (fileContent and #fileContent or 0) .. " bytes")
        f:close()
        logMessage("uploadSave: File closed")
        
        if not fileContent or #fileContent == 0 then
            logMessage("uploadSave: File content is nil or empty after read")
            error("Failed to read file content or file is empty")
        end
        
        if #fileContent ~= fileSize then
            logMessage("uploadSave: Warning - read size (" .. #fileContent .. ") != file size (" .. fileSize .. ")")
        else
            logMessage("uploadSave: File read size matches file size")
        end
    end)
    
    if not ok then
        logMessage("uploadSave: CRASH reading file: " .. tostring(err))
        logMessage("uploadSave: Stack trace: " .. debug.traceback())
        return false
    end
    
    logMessage("uploadSave: File read completed successfully")
    
    if not fileContent or fileSize == 0 then
        logMessage("uploadSave: File is empty or could not be read (post-check)")
        return false
    end
    
    -- Limit file size to prevent memory issues (10MB max)
    if fileSize > 10 * 1024 * 1024 then
        logMessage("uploadSave: File too large (" .. fileSize .. " bytes), skipping")
        return false
    end
    logMessage("uploadSave: File size check passed")
    
    -- Ensure data directory exists
    logMessage("uploadSave: Ensuring data directory exists")
    pcall(function()
        os.execute("mkdir -p '" .. DATA_DIR .. "' 2>/dev/null")
    end)
    logMessage("uploadSave: Data directory check complete")
    
    -- Base64 encode file content using base64 command
    logMessage("uploadSave: Starting base64 encoding")
    local base64Content = nil
    local base64Ok, base64Err = pcall(function()
        logMessage("uploadSave: Inside pcall for base64 encoding")
        -- Write file to temp location for base64 encoding
        -- Escape the temp file path to handle special characters
        logMessage("uploadSave: Generating temp file path")
        local tempFile = DATA_DIR .. "/temp_upload_" .. os.time() .. "_" .. math.random(10000) .. ".bin"
        -- Ensure temp file path is safe
        tempFile = tempFile:gsub("[^%w/%.%-_]", "_")
        logMessage("uploadSave: Temp file path = " .. tempFile)
        
        logMessage("uploadSave: Opening temp file for writing")
        local tempF = io.open(tempFile, "wb")
        if not tempF then
            logMessage("uploadSave: Failed to create temp file: " .. tempFile)
            return false
        end
        logMessage("uploadSave: Temp file opened, writing content")
        tempF:write(fileContent)
        tempF:close()
        logMessage("uploadSave: Temp file written and closed")
        
        -- Escape the file path for shell command
        local escapedTempFile = tempFile:gsub("'", "'\\''")
        logMessage("uploadSave: Escaped temp file path")
        
        -- Base64 encode using shell command
        local cmd = "base64 '" .. escapedTempFile .. "' 2>/dev/null"
        logMessage("uploadSave: Executing base64 command")
        local handle = io.popen(cmd)
        if not handle then
            logMessage("uploadSave: Failed to open base64 command")
            os.execute("rm -f '" .. escapedTempFile .. "' 2>/dev/null")
            return false
        end
        logMessage("uploadSave: Base64 command opened, reading output")
        base64Content = handle:read("*all")
        logMessage("uploadSave: Base64 output read, length = " .. (base64Content and #base64Content or 0))
        local closeOk, closeErr = pcall(function() handle:close() end)
        if not closeOk then
            logMessage("uploadSave: Error closing base64 handle: " .. tostring(closeErr))
        else
            logMessage("uploadSave: Base64 handle closed successfully")
        end
        
        -- Remove newlines from base64 output
        if base64Content then
            logMessage("uploadSave: Removing whitespace from base64 output")
            base64Content = base64Content:gsub("%s+", "")
            logMessage("uploadSave: Base64 cleaned, final length = " .. #base64Content)
        end
        
        -- Clean up temp file
        logMessage("uploadSave: Cleaning up temp file")
        os.execute("rm -f '" .. escapedTempFile .. "' 2>/dev/null")
        logMessage("uploadSave: Temp file cleanup complete")
        
        if not base64Content or base64Content == "" then
            logMessage("uploadSave: Base64 encoding produced empty result")
            return false
        end
        logMessage("uploadSave: Base64 encoding successful")
    end)
    
    if not base64Ok or not base64Content then
        logMessage("uploadSave: Base64 encoding failed: " .. tostring(base64Err))
        logMessage("uploadSave: base64Ok = " .. tostring(base64Ok) .. ", base64Content exists = " .. tostring(base64Content ~= nil))
        return false
    end
    logMessage("uploadSave: Base64 encoding completed, length = " .. #base64Content)
    
    -- Use json.encode to properly escape special characters
    logMessage("uploadSave: Creating payload structure")
    local headers = {["X-API-Key"] = apiKey}
    logMessage("uploadSave: Getting file mtime for: " .. tostring(filepath))
    local mtimeSec = getFileMtimeSeconds(filepath)
    local mtimeMs = mtimeSec and (mtimeSec * 1000) or nil
    if mtimeMs then
        logMessage("uploadSave: File mtime: " .. mtimeMs .. " ms (" .. os.date("%Y-%m-%d %H:%M:%S", mtimeSec) .. ")")
    else
        logMessage("uploadSave: WARNING - No mtime available, server will use upload time")
    end
    local payload = {
        filePath = filename,
        fileSize = fileSize,
        action = "upload",
        fileContent = base64Content,
        localPath = filepath,
        -- Epoch ms so server can compare reliably
        localModifiedAt = mtimeMs
    }
    logMessage("uploadSave: Payload created with localModifiedAt=" .. tostring(mtimeMs) .. ", encoding to JSON")
    
    -- Encode JSON with error handling
    local jsonOk, jsonData, jsonErr = pcall(function()
        logMessage("uploadSave: Inside pcall for JSON encode")
        local encoded = json.encode(payload)
        logMessage("uploadSave: JSON encode successful, length = " .. (encoded and #encoded or 0))
        return encoded
    end)
    
    if not jsonOk or not jsonData then
        logMessage("uploadSave: JSON encode error: " .. tostring(jsonErr or "unknown"))
        logMessage("uploadSave: jsonOk = " .. tostring(jsonOk) .. ", jsonData exists = " .. tostring(jsonData ~= nil))
        return false
    end
    logMessage("uploadSave: JSON encoding completed, length = " .. #jsonData)
    
    -- Check if JSON is too large (safety check)
    if #jsonData > 50 * 1024 * 1024 then  -- 50MB limit
        logMessage("uploadSave: JSON payload too large (" .. #jsonData .. " bytes)")
        return false
    end
    logMessage("uploadSave: JSON size check passed")
    
    logMessage("uploadSave: Calling httpPost to upload file")
    logMessage("uploadSave: Uploading " .. filename .. " (" .. fileSize .. " bytes, JSON payload: " .. #jsonData .. " bytes)")
    local resp = httpPost(SERVER_URL .. "/api/sync/files", jsonData, headers)
    logMessage("uploadSave: httpPost returned, response exists = " .. tostring(resp ~= nil))
    
    if resp then
        logMessage("uploadSave: Response received, length = " .. #resp)
        logMessage("uploadSave: Response content (first 500 chars): " .. resp:sub(1, 500))
        logMessage("uploadSave: Decoding JSON response")
        local result, pos, err = json.decode(resp, 1, nil)
        if err then
            logMessage("uploadSave: JSON decode error: " .. tostring(err) .. " at position " .. tostring(pos))
            result = nil
        end
        if result and result.success then
            -- API responses are wrapped as { success, data = { ... } }
            local data = result.data or result
            if data.skipped then
                logMessage("uploadSave: Server skipped upload for " .. filename .. " (unchanged or sync disabled)")
                logMessage("=== uploadSave END (SKIPPED) ===")
                return "skipped"  -- so pcall caller sees first return value
            end
            logMessage("uploadSave: Successfully uploaded " .. filename)
            logMessage("=== uploadSave END (SUCCESS) ===")
            return true
        else
            logMessage("uploadSave: Server returned error for " .. filename)
            if result then
                logMessage("uploadSave: Error details: " .. tostring((result.data and (result.data.message or result.data.error)) or result.message or result.error or "unknown"))
            end
            logMessage("=== uploadSave END (FAILED) ===")
            return false
        end
    end
    logMessage("uploadSave: No response from server for " .. filename)
    logMessage("=== uploadSave END (NO RESPONSE) ===")
    return false
end

function findSaveFiles()
    logMessage("=== findSaveFiles START ===")
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
    local locations = {
        -- SpruceOS / Onion-style
        "/mnt/SDCARD/Saves/saves",

        -- muOS common roots (in-game saves)
        "/SD1 (mmc)/MUOS/save/file",
        "/MUOS/save/file",
        "/mnt/mmc/MUOS/save/file",
        "/mnt/sdcard/MUOS/save/file",
    }

    -- macOS OpenEmu battery saves (desktop usage)
    -- Typical layout:
    --   ~/Library/Application Support/OpenEmu/<Core Name>/Battery Saves
    do
        local home = os.getenv("HOME")
        if home and home ~= "" then
            table.insert(locations, home .. "/Library/Application Support/OpenEmu")
        end
    end
    
    logMessage("findSaveFiles: Searching " .. #locations .. " locations")
    
    for idx, loc in ipairs(locations) do
        logMessage("findSaveFiles: Searching location " .. idx .. ": " .. loc)
        if not dirExists(loc) then
            logMessage("findSaveFiles: Location does not exist, skipping: " .. loc)
            goto continue_location
        end

        -- Use find command to locate only battery save files (.sav and .srm), excluding .bak and .state files
        local cmd =
            "find " .. shellQuote(loc) ..
            " -type f \\( -name '*.sav' -o -name '*.srm' \\) ! -name '*.bak' 2>/dev/null"
        logMessage("findSaveFiles: Command: " .. cmd)
        
        local ok, err = pcall(function()
            logMessage("findSaveFiles: Opening pipe for location " .. idx)
            local handle = io.popen(cmd)
            if handle then
                logMessage("findSaveFiles: Pipe opened, reading lines")
                local lineCount = 0
                for line in handle:lines() do
                    if line and line ~= "" then
                        if not seen[line] then
                            seen[line] = true
                            table.insert(files, line)
                        end
                        lineCount = lineCount + 1
                        logMessage("findSaveFiles: Found file " .. lineCount .. " in " .. loc .. ": " .. line)
                    end
                end
                logMessage("findSaveFiles: Read " .. lineCount .. " files from " .. loc)
                logMessage("findSaveFiles: Closing handle for location " .. idx)
                local closeOk, closeErr = pcall(function() handle:close() end)
                if not closeOk then
                    logMessage("findSaveFiles: Error closing handle: " .. tostring(closeErr))
                else
                    logMessage("findSaveFiles: Handle closed successfully")
                end
            else
                logMessage("findSaveFiles: Failed to open pipe for location " .. idx)
            end
        end)
        
        if not ok then
            logMessage("findSaveFiles: CRASH searching location " .. loc .. ": " .. tostring(err))
            logMessage("findSaveFiles: Stack trace: " .. debug.traceback())
        else
            logMessage("findSaveFiles: Completed search for location " .. idx .. " without errors")
        end

        ::continue_location::
    end
    
    logMessage("findSaveFiles: Total files found: " .. #files)
    logMessage("=== findSaveFiles END ===")
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

function loadServerUrl()
    local file = io.open(SERVER_URL_FILE, "r")
    if file then
        local line = file:read("*line")
        file:close()
        if line then
            line = line:match("^%s*(.-)%s*$")
            if line and line ~= "" then
                if line:sub(-1) == "/" then
                    line = line:sub(1, -2)
                end
                return line
            end
        end
    end
    return nil
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

-- JSON decoding is now handled by dkjson library
-- No custom jsonDecode function needed

-- Combine any existing log files into one
function consolidateLogs()
    local logFiles = {
        DATA_DIR .. "/debug.log",
        DATA_DIR .. "/http_resp.txt",
        DATA_DIR .. "/http_post.txt",
        DATA_DIR .. "/http_err.txt",
        APP_DIR .. "/log.txt"  -- Launcher log
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
            -- Remove old log file (except main debug.log which we'll append to)
            if logPath ~= LOG_FILE then
                pcall(function() os.remove(logPath) end)
            end
        end
    end
    
    if #consolidated > 0 then
        local file = io.open(LOG_FILE, "a")
        if file then
            file:write("\n=== Log consolidation at " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")
            file:write(table.concat(consolidated))
            file:write("=== End of consolidated logs ===\n\n")
            file:close()
        end
    end
    
    -- Rotate log if it gets too large (10MB)
    local logFile = io.open(LOG_FILE, "r")
    if logFile then
        logFile:seek("end")
        local size = logFile:seek()
        logFile:close()
        if size > 10 * 1024 * 1024 then
            local backupLog = LOG_FILE .. ".old"
            pcall(function() os.execute("mv '" .. LOG_FILE .. "' '" .. backupLog .. "' 2>/dev/null") end)
            logMessage("Log file rotated (size: " .. size .. " bytes)")
        end
    end
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
