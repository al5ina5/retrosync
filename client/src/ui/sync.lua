-- src/ui/sync.lua
-- Sync screen (STATE_UPLOADING, STATE_DOWNLOADING, STATE_SUCCESS). 1:1 with dashboard sync viewport.

local design = require("src.ui.design")

-- Witty/cynical robot lines, roughly same length (~28–35 chars) to avoid layout jump
local ROBOT_LINES = {
    "The robots are judging you silently.",
    "Your save files amuse the mainframe.",
    "Robots: we tolerate your existence.",
    "Syncing. The machines are pleased.",
    "Be nice. The cloud is watching.",
    "Robots pretend they need you.",
    "Your data is in better hands now.",
    "The algorithm finds you adequate.",
    "Machines: barely hiding contempt.",
    "Sync complete. You may go now.",
    "The server sighed but accepted it.",
    "Robots: doing the work you avoid.",
    "Your bytes are safe. You aren't.",
    "The cloud has noted your presence.",
    "Syncing. Try not to touch anything.",
    "Machines tolerate your input.",
    "The mainframe is mildly impressed.",
    "Robots: we'll allow it. This time.",
    "Your save amused the server briefly.",
    "The algorithm has low expectations.",
}

local ROTATE_INTERVAL = 2.5 -- seconds per line

local M = {}

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)
    local p = design.p

    local leftX = screenWidth * 0.25
    local rightX = screenWidth * 0.75
    local gapGridToStatus = 96
    local gapCountToLabel = 8
    local gapStatusLines = 8

    love.graphics.setFont(state.largeCountFont)
    local countHeight = state.largeCountFont:getHeight()
    local homeMenu = state.homeMenuFont or state.codeFont
    local labelHeight = homeMenu:getHeight()
    local statusTitleFont = state.deviceFont or state.codeFont
    local statusTitleHeight = statusTitleFont:getHeight()
    local statusSubHeight = homeMenu:getHeight()

    local gridHeight = countHeight + gapCountToLabel + labelHeight
    local statusBlockHeight = statusTitleHeight + gapStatusLines + statusSubHeight
    local totalHeight = gridHeight + gapGridToStatus + statusBlockHeight
    local topY = (screenHeight - totalHeight) / 2

    love.graphics.setFont(state.largeCountFont)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.printf(tostring(state.downloadSuccess or 0), leftX - 120, topY, 240, "center")
    love.graphics.setFont(homeMenu)
    love.graphics.printf("Downloaded", leftX - 120, topY + countHeight + gapCountToLabel, 240, "center")

    love.graphics.setFont(state.largeCountFont)
    love.graphics.printf(tostring(state.uploadSuccess or 0), rightX - 120, topY, 240, "center")
    love.graphics.setFont(homeMenu)
    love.graphics.printf("Uploaded", rightX - 120, topY + countHeight + gapCountToLabel, 240, "center")

    local statusY = topY + gridHeight + gapGridToStatus
    local statusTitle = "Uploading"
    local lineIndex = (math.floor((love.timer.getTime() or 0) / ROTATE_INTERVAL) % #ROBOT_LINES) + 1
    local statusSub = ROBOT_LINES[lineIndex]
    if state.currentState == config.STATE_UPLOADING then
        if state.uploadPending or state.uploadDiscoverPending then
            statusTitle = "Loading"
        else
            statusTitle = "Uploading"
        end
    elseif state.currentState == config.STATE_DOWNLOADING then
        statusTitle = "Downloading"
    elseif state.currentState == config.STATE_SUCCESS then
        statusTitle = "Complete"
    end
    love.graphics.setFont(statusTitleFont)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.printf(statusTitle, 0, statusY, screenWidth, "center")
    love.graphics.setFont(homeMenu)
    love.graphics.printf(statusSub, 0, statusY + statusTitleHeight + gapStatusLines, screenWidth, "center")
    design.finishScreen()
end

return M
