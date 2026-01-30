-- src/ui/showing_files.lua
-- Recent saves list (STATE_SHOWING_FILES). Uses design system.

local design = require("src.ui.design")

local M = {}

function M.draw(state, config, ui)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)

    local layout = design.listLayout(screenWidth, screenHeight, state)
    design.setContentScissor(screenWidth, screenHeight)

    love.graphics.setFont(layout.titleFont)
    love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
    local count = #state.savesList
    local titleStr = count == 0 and "Recent Saves" or (tostring(count) .. " Recent Saves")
    love.graphics.print(titleStr, layout.contentPadding, layout.contentPadding)

    local listAreaH = screenHeight - layout.listTopY - layout.contentPadding
    local maxVisibleLines = math.floor(listAreaH / (layout.rowHeight + layout.gapMenu))
    if maxVisibleLines < 1 then maxVisibleLines = 1 end

    if state.filesListLoading then
        love.graphics.setFont(layout.menuFont)
        love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
        love.graphics.print("Loading...", layout.contentPadding, layout.listTopY)
    elseif state.filesListError ~= "" then
        love.graphics.setFont(layout.menuFont)
        love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
        love.graphics.print(state.filesListError, layout.contentPadding, layout.listTopY)
    elseif count == 0 then
        love.graphics.setFont(layout.menuFont)
        love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
        love.graphics.print("No saves yet", layout.contentPadding, layout.listTopY)
    else
        local totalLines = count
        if state.filesListSelectedIndex < 1 then state.filesListSelectedIndex = 1
        elseif state.filesListSelectedIndex > totalLines then state.filesListSelectedIndex = totalLines end
        if state.filesListSelectedIndex <= state.filesListScroll then
            state.filesListScroll = state.filesListSelectedIndex - 1
        elseif state.filesListSelectedIndex > state.filesListScroll + maxVisibleLines then
            state.filesListScroll = state.filesListSelectedIndex - maxVisibleLines
        end
        local startIdx = math.max(1, state.filesListScroll + 1)
        local endIdx = math.min(totalLines, startIdx + maxVisibleLines - 1)

        for i = startIdx, endIdx do
            local save = state.savesList[i]
            local listIdx = i - startIdx
            local rowY = layout.listTopY + listIdx * (layout.rowHeight + layout.gapMenu)
            local isSelected = (i == state.filesListSelectedIndex)
            local displayName = save.name or "Unknown"
            displayName = ui.truncateToWidth(displayName, layout.maxTextW, layout.menuFont)
            design.drawListRow(rowY, displayName, isSelected, layout)
        end
    end

    design.clearScissor()
    design.finishScreen()
end

return M
