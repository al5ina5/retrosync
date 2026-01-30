-- src/ui/confirm.lua
-- Generic confirmation screen (STATE_CONFIRM). Message + Yes/No; used for unpair and other settings.
-- Layout matches dashboard client page: centered message (text-center max-w-md), smaller centered buttons (px-4 py-2, space-y-1).

local design = require("src.ui.design")

local M = {}

-- Gap between message and options block (matches space-y-12 = 48px)
local GAP_MESSAGE_TO_OPTIONS = 48
-- Gap between Yes and No (matches space-y-1 = 4px)
local GAP_OPTIONS = 4

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)

    local p = design.p
    local pad = design.P12
    local buttonPadH, buttonPadV = design.PX4, design.PY2
    local font = state.homeMenuFont or state.codeFont
    local lineH = font:getHeight()
    local msg = state.confirmMessage or "Confirm?"
    local yesLabel = state.confirmYesLabel or "Yes"
    local noLabel = state.confirmNoLabel or "No"
    local sel = state.confirmSelectedIndex
    if sel < 1 then state.confirmSelectedIndex = 1; sel = 1
    elseif sel > 2 then state.confirmSelectedIndex = 2; sel = 2 end

    -- Content width for message wrap (matches max-w-md)
    local _, _, contentW = design.contentBox(screenWidth, screenHeight, pad)
    local rowHeight = buttonPadV + lineH + buttonPadV
    local maxLabelW = math.max(font:getWidth(yesLabel), font:getWidth(noLabel))
    local optionWidth = maxLabelW + buttonPadH * 2
    local optionX = (screenWidth - optionWidth) / 2
    local textOffsetY = buttonPadV

    -- Vertical center: message block + gap (space-y-12) + options block (2 rows, space-y-1)
    local _, wrappedLines = font:getWrap(msg, contentW)
    local msgLines = (wrappedLines and #wrappedLines > 0) and #wrappedLines or 1
    local msgH = msgLines * lineH
    local optionsBlockH = rowHeight * 2 + GAP_OPTIONS
    local totalH = msgH + GAP_MESSAGE_TO_OPTIONS + optionsBlockH
    local blockTopY = (screenHeight - totalH) / 2

    -- Message: centered, wrapped at blockTopY
    love.graphics.setFont(font)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.printf(msg, pad, blockTopY, contentW, "center")

    local optionsTopY = blockTopY + msgH + GAP_MESSAGE_TO_OPTIONS
    local row1Y = optionsTopY
    local row2Y = row1Y + rowHeight + GAP_OPTIONS

    love.graphics.setFont(font)
    if sel == 1 then
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB)
        love.graphics.rectangle("fill", optionX, row1Y, optionWidth, rowHeight)
    end
    if sel == 2 then
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB)
        love.graphics.rectangle("fill", optionX, row2Y, optionWidth, rowHeight)
    end
    if sel == 1 then
        love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
    else
        love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    end
    love.graphics.printf(yesLabel, 0, row1Y + textOffsetY, screenWidth, "center")
    if sel == 2 then
        love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
    else
        love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    end
    love.graphics.printf(noLabel, 0, row2Y + textOffsetY, screenWidth, "center")

    design.finishScreen()
end

return M
