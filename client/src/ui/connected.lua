-- src/ui/connected.lua
-- Home screen (STATE_CONNECTED). 1:1 with dashboard client page first viewport.

local design = require("src.ui.design")

local M = {}

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)
    local p = design.p

    local contentPadding = 24   -- home uses p-6 (24px), not p-12
    local gapBlock = 48
    local gapMenu = 4
    local buttonPadH, buttonPadV = design.PX4, design.PY2
    local contentW = screenWidth - contentPadding * 2
    local contentH = screenHeight - contentPadding * 2
    local homeTitle = state.homeTitleFont or state.titleFont
    local homeMenu = state.homeMenuFont or state.codeFont
    local titleHeight = homeTitle:getHeight()
    local menuLineHeight = homeMenu:getHeight()
    local rowHeight = buttonPadV + menuLineHeight + buttonPadV
    local menuBlockHeight = rowHeight + gapMenu + rowHeight + gapMenu + rowHeight
    local deviceHeight = menuLineHeight
    local totalBlockH = titleHeight + gapBlock + menuBlockHeight + gapBlock + deviceHeight
    local blockTopY = contentPadding + (contentH - totalBlockH) / 2

    local title = "RETROSYNC"
    love.graphics.setFont(homeTitle)
    local titleY = blockTopY
    local totalWidth = homeTitle:getWidth(title)
    local startX = (screenWidth - totalWidth) / 2
    local letterCount = #title
    local fallDuration = 0.35
    local stagger = (config.homeIntroDuration - fallDuration) / math.max(letterCount - 1, 1)
    local x = startX
    for i = 1, letterCount do
        local ch = title:sub(i, i)
        local charWidth = homeTitle:getWidth(ch)
        local charStart = (i - 1) * stagger
        local charT = (state.homeIntroTimer - charStart) / fallDuration
        if charT > 0 then
            if charT > 1 then charT = 1 end
            local eased = charT * charT * (3 - 2 * charT)
            local overshoot = math.sin(eased * math.pi) * 8
            local y = titleY - (1 - eased) * 80 + overshoot
            local sway = math.sin((state.homeIntroTimer * 10) + i * 0.7) * (1 - charT) * 2
            love.graphics.setColor(p.darkR, p.darkG, p.darkB)
            love.graphics.print(ch, x + sway, y)
        end
        x = x + charWidth
    end

    local buttonsStart = config.homeIntroDuration * 0.4
    local buttonsT = 0
    if state.homeIntroTimer > buttonsStart then
        buttonsT = math.max(0, math.min(1, (state.homeIntroTimer - buttonsStart) / (config.homeIntroDuration - buttonsStart)))
    end
    local alpha = buttonsT

    local row1Y = blockTopY + titleHeight + gapBlock
    local row2Y = row1Y + rowHeight + gapMenu
    local row3Y = row2Y + rowHeight + gapMenu
    local deviceY = blockTopY + titleHeight + gapBlock + menuBlockHeight + gapBlock

    local maxLabelW = math.max(homeMenu:getWidth("SYNC"), homeMenu:getWidth("RECENT"), homeMenu:getWidth("SETTINGS"))
    local optionWidth = maxLabelW + buttonPadH * 2
    local optionX = (screenWidth - optionWidth) / 2
    local textOffsetY = buttonPadV

    love.graphics.setFont(homeMenu)
    local sel = state.homeSelectedIndex
    if sel == 1 then
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB, alpha)
        love.graphics.rectangle("fill", optionX, row1Y, optionWidth, rowHeight)
    elseif sel == 2 then
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB, alpha)
        love.graphics.rectangle("fill", optionX, row2Y, optionWidth, rowHeight)
    elseif sel == 3 then
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB, alpha)
        love.graphics.rectangle("fill", optionX, row3Y, optionWidth, rowHeight)
    end
    if sel == 1 then love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB, alpha)
    else love.graphics.setColor(p.darkR, p.darkG, p.darkB, alpha) end
    love.graphics.printf("SYNC", 0, row1Y + textOffsetY, screenWidth, "center")
    if sel == 2 then love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB, alpha)
    else love.graphics.setColor(p.darkR, p.darkG, p.darkB, alpha) end
    love.graphics.printf("RECENT", 0, row2Y + textOffsetY, screenWidth, "center")
    if sel == 3 then love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB, alpha)
    else love.graphics.setColor(p.darkR, p.darkG, p.darkB, alpha) end
    love.graphics.printf("SETTINGS", 0, row3Y + textOffsetY, screenWidth, "center")

    if state.deviceName then
        love.graphics.setFont(homeMenu)
        local deviceStr = "DEVICE: " .. state.deviceName:upper()
        local deviceW = homeMenu:getWidth(deviceStr)
        love.graphics.setColor(p.darkR, p.darkG, p.darkB, alpha * 0.5)
        love.graphics.print(deviceStr, (screenWidth - deviceW) / 2, deviceY)
    end

    -- No paths configured: show overlay when no scan paths (paths sync with server; manageable via web dashboard).
    local paths = state.scanPathEntries or {}
    if #paths == 0 and not state.noPathsMessageDismissed then
        local PAD = design.P12
        local GAP = design.SPACE_Y_6
        love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB, 0.95)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        local msgFont = state.deviceFont or state.codeFont
        local subFont = state.smallFont or state.deviceFont
        local msg = "RetroSync has not detected any paths with save files. To add a path, drag and drop a folder onto the RetroSync app's window at anytime or enter your device settings on your dashboard."
        local _, _, contentW = design.contentBox(screenWidth, screenHeight, PAD)
        local _, wrapped = msgFont:getWrap(msg, contentW)
        local lineCount = wrapped and #wrapped or 1
        local lineH = msgFont:getHeight()
        local msgH = lineH * lineCount
        local dismissStr = "Dismiss with A or click"
        local dismissH = subFont:getHeight()
        local totalH = msgH + GAP + dismissH
        local blockTopY = (screenHeight - totalH) / 2
        love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
        love.graphics.setFont(msgFont)
        love.graphics.printf(msg, PAD, blockTopY, contentW, "center")
        love.graphics.setFont(subFont)
        love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB, 0.9)
        love.graphics.printf(dismissStr, PAD, blockTopY + msgH + GAP, contentW, "center")
    end

    design.finishScreen()
end

-- Returns true when the "no paths" overlay is visible (so input can dismiss on A or click).
function M.isNoPathsOverlayVisible(state, config)
    local paths = state.scanPathEntries or {}
    return state.currentState == config.STATE_CONNECTED and #paths == 0 and not state.noPathsMessageDismissed
end

return M
