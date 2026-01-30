-- src/ui/device_history.lua
-- History (this device) list (STATE_DEVICE_HISTORY).

local M = {}

function M.draw(state, config, ui)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    love.graphics.setFont(state.titleFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("HISTORY (THIS DEVICE)", 0, 20, screenWidth, "center")
    if #state.deviceHistory == 0 then
        love.graphics.setFont(state.codeFont)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf("No history yet", 0, 120, screenWidth, "center")
    else
        local listStartY = 120
        local lineHeight = 32
        local bottomMargin = 20
        local maxVisibleLines = math.floor((screenHeight - listStartY - bottomMargin) / lineHeight)
        local totalLines = #state.deviceHistory
        if state.historySelectedIndex < 1 then state.historySelectedIndex = 1
        elseif state.historySelectedIndex > totalLines then state.historySelectedIndex = totalLines end
        if state.historySelectedIndex <= state.historyScroll then
            state.historyScroll = state.historySelectedIndex - 1
        elseif state.historySelectedIndex > state.historyScroll + maxVisibleLines then
            state.historyScroll = state.historySelectedIndex - maxVisibleLines
        end
        local startIdx = math.max(1, state.historyScroll + 1)
        local endIdx = math.min(totalLines, startIdx + maxVisibleLines - 1)
        if totalLines > maxVisibleLines then
            love.graphics.setFont(state.codeFont)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.printf("(" .. startIdx .. "-" .. endIdx .. " / " .. totalLines .. ")", 0, listStartY - 25, screenWidth, "center")
        end
        love.graphics.setFont(state.codeFont)
        for i = startIdx, endIdx do
            local entry = state.deviceHistory[i]
            local y = listStartY + (i - startIdx) * lineHeight
            local isSelected = (i == state.historySelectedIndex)
            if isSelected then
                love.graphics.setColor(0.2, 0.4, 0.6)
                love.graphics.rectangle("fill", 10, y - 2, screenWidth - 20, lineHeight - 2, 5, 5)
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.9, 0.9, 0.9)
            end
            local dir = (entry.direction == "upload") and "↑" or "↓"
            local dirColor = (entry.direction == "upload") and {0.4, 1.0, 0.6} or {0.4, 0.7, 1.0}
            local paddingLeft = 24
            local paddingRight = 20
            local midY = y + 2
            local name = entry.name or "Unknown"
            local maxNameW = (screenWidth - paddingLeft - paddingRight) * 0.6
            name = ui.truncateToWidth(name, maxNameW, state.codeFont)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(name, paddingLeft, midY, maxNameW, "left")
            local relTime = ui.formatHistoryTime(entry.ts)
            local rightText = dir .. " " .. relTime
            love.graphics.setColor(dirColor[1], dirColor[2], dirColor[3])
            love.graphics.printf(rightText, paddingLeft, midY, screenWidth - paddingLeft - paddingRight, "right")
        end
    end
    love.graphics.setFont(state.deviceFont or state.codeFont)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("UP/DOWN to scroll, B/ESC to go back", 20, screenHeight - 50, screenWidth - 40, "center")
end

return M
