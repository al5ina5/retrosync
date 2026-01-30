-- src/ui/showing_code.lua
-- Pairing code screen (STATE_SHOWING_CODE). 1:1 with dashboard client page pairing viewport.

local design = require("src.ui.design")

local M = {}

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)
    local p = design.p

    -- 1:1 with dashboard: space-y-12=48px, text-4xl title, code block (text-5xl + space-y-1 + label), opacity-50 Waiting...
    -- Comment: Add motion to the 3 dots... typing over and over again...
    local gapBlock = 48   -- space-y-12
    local gapCodeToLabel = 4   -- space-y-1 between code value and "Your Pairing Code"

    local titleFont = state.homeTitleFont or state.titleFont   -- text-4xl = 36px
    local codeValueFont = state.titleFont   -- text-5xl = 48px
    local labelFont = state.homeMenuFont or state.codeFont    -- base = 16px

    local titleHeight = titleFont:getHeight()
    local codeValueHeight = codeValueFont:getHeight()
    local labelHeight = labelFont:getHeight()
    local codeBlockHeight = codeValueHeight + gapCodeToLabel + labelHeight
    local statusHeight = labelFont:getHeight()
    local totalBlockH = titleHeight + gapBlock + codeBlockHeight + gapBlock + statusHeight
    local blockTopY = (screenHeight - totalBlockH) / 2

    -- Title: "RetroSync" (text-4xl), centered
    love.graphics.setFont(titleFont)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    local title = "RETROSYNC"
    love.graphics.printf(title, 0, blockTopY, screenWidth, "center")

    -- Code block: code value (text-5xl) then "Your Pairing Code" (space-y-1)
    local codeBlockTopY = blockTopY + titleHeight + gapBlock
    local codeValueY = codeBlockTopY
    local labelY = codeValueY + codeValueHeight + gapCodeToLabel

    love.graphics.setFont(codeValueFont)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.printf(state.deviceCode or "------", 0, codeValueY, screenWidth, "center")

    love.graphics.setFont(labelFont)
    love.graphics.printf("Your Pairing Code", 0, labelY, screenWidth, "center")

    -- Waiting... with animated dots (motion to the 3 dots, typing over and over again)
    local statusY = codeBlockTopY + codeBlockHeight + gapBlock
    local dots = math.floor(state.pollIndicator * 2) % 4
    local dotStr = ""
    for i = 1, dots do dotStr = dotStr .. "." end
    love.graphics.setFont(labelFont)
    if state.pairingError == "" then
        love.graphics.setColor(p.darkR, p.darkG, p.darkB, 0.5)
        love.graphics.printf("Waiting" .. dotStr, 0, statusY, screenWidth, "center")
    else
        love.graphics.setColor(p.darkR, p.darkG, p.darkB, 0.9)
        love.graphics.printf(state.pairingError, 0, statusY, screenWidth, "center")
    end

    design.finishScreen()
end

return M
