-- src/ui/design.lua
-- Design system: spacing, palette, and shared screen/list helpers.
-- Use from ui screens for consistent layout and easy expansion.

local palette = require("src.ui.palette")

local M = {}

-- Re-export palette so screens can use design.palette or require design only
M.palette = palette
M.p = palette

-- Spacing (Tailwind-aligned: p-12=48, space-y-6=24, space-y-2=8, px-4=16, py-2=8)
M.P12 = 48
M.SPACE_Y_6 = 24
M.SPACE_Y_2 = 8
M.PX4 = 16
M.PY2 = 8
M.BORDER_WIDTH = 2

-- Content box inside p-12 margin: returns x, y, width, height
function M.contentBox(screenWidth, screenHeight, padding)
    padding = padding or M.P12
    return padding, padding, screenWidth - padding * 2, screenHeight - padding * 2
end

-- Draw full-screen background (lightest) and dark border; call before content
function M.drawScreenWithBorder(screenWidth, screenHeight)
    local p = palette
    love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.setLineWidth(M.BORDER_WIDTH)
    love.graphics.rectangle("line", 1, 1, screenWidth - 2, screenHeight - 2)
end

-- Clip drawing to content area (p-12). Call before drawing title/list; clear after.
function M.setContentScissor(screenWidth, screenHeight, padding)
    padding = padding or M.P12
    local x, y, w, h = M.contentBox(screenWidth, screenHeight, padding)
    love.graphics.setScissor(x, y, w, h)
end

function M.clearScissor()
    love.graphics.setScissor()
end

-- Call at end of screen draw when using drawScreenWithBorder (resets line width)
function M.finishScreen()
    love.graphics.setLineWidth(1)
end

-- Compute list layout for "title + list" screens (Settings, Recent).
-- Returns: contentPadding, contentW, contentH, gapTitleToList, gapMenu, buttonPadH, buttonPadV,
--          titleHeight, rowHeight, listTopY, textX, maxTextW
function M.listLayout(screenWidth, screenHeight, state)
    local pad = M.P12
    local gapTitle = M.SPACE_Y_6
    local gapMenu = M.SPACE_Y_2
    local buttonPadH, buttonPadV = M.PX4, M.PY2
    local _, _, contentW, contentH = M.contentBox(screenWidth, screenHeight, pad)
    local menuFont = state.homeMenuFont or state.codeFont
    local titleFont = state.deviceFont or state.codeFont
    local menuLineHeight = menuFont:getHeight()
    local titleHeight = titleFont:getHeight()
    local rowHeight = buttonPadV + menuLineHeight + buttonPadV
    local listTopY = pad + titleHeight + gapTitle
    local textX = pad + buttonPadH
    local maxTextW = contentW - buttonPadH * 2
    return {
        contentPadding = pad,
        contentW = contentW,
        contentH = contentH,
        gapTitleToList = gapTitle,
        gapMenu = gapMenu,
        buttonPadH = buttonPadH,
        buttonPadV = buttonPadV,
        titleHeight = titleHeight,
        rowHeight = rowHeight,
        listTopY = listTopY,
        textX = textX,
        maxTextW = maxTextW,
        menuFont = menuFont,
        titleFont = titleFont,
    }
end

-- Draw a single list row (left-aligned): optional selected bg, then label.
-- rowY, label, selected, layout = from listLayout()
function M.drawListRow(rowY, label, selected, layout)
    local p = palette
    local font = layout.menuFont
    love.graphics.setFont(font)
    if selected then
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB)
        love.graphics.rectangle("fill", layout.contentPadding, rowY, layout.contentW, layout.rowHeight)
    end
    if selected then
        love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
    else
        love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    end
    love.graphics.print(label, layout.textX, rowY + layout.buttonPadV)
end

return M
