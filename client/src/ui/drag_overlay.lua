-- src/ui/drag_overlay.lua
-- Drag/drop overlay (macOS/Windows/Linux). Matches dashboard client page: bg-gameboy-darkest/90,
-- text-gameboy-lightest, p-12 space-y-6, centered. Two states: (1) "Release to add path" while
-- dragging; (2) "Path added to Sync. Now tracking." + truncated path line after drop.

local design = require("src.ui.design")

local M = {}

local PAD = design.P12
local GAP = design.SPACE_Y_6  -- space-y-6 = 24px

function M.draw(state, config, ui)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local isPathAdded = state.pathAddedAt and (love.timer.getTime() - state.pathAddedAt) < config.PATH_ADDED_DURATION
    local isDragging = state.dragOverWindow and not isPathAdded

    if not isPathAdded and not isDragging then
        return
    end

    local p = design.p

    -- Full-screen overlay: bg-gameboy-darkest/90
    love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Content: p-12, space-y-6, centered. Text in lightest (text-gameboy-lightest).
    -- Path line uses tiny font (state.smallFont) so more of the path fits before truncation.
    local titleFont = state.titleFont or state.codeFont
    local subFont = state.smallFont or state.deviceFont or state.codeFont
    local titleH = titleFont:getHeight()
    local subH = subFont:getHeight()
    local _, _, contentW = design.contentBox(screenWidth, screenHeight, PAD)

    local mainText
    local subText

    if isPathAdded then
        -- State 1: "Path added to Sync. Now tracking." + path (one line, truncate)
        mainText = "Path added to Sync. Now tracking."
        local rawPath = state.pathAddedMessage or ""
        subText = (rawPath ~= "") and ui.truncateToWidth(rawPath, contentW, subFont) or ""
    else
        -- State 2: "Release to add path"
        mainText = "Release to add path"
        subText = nil
    end

    -- Use wrapped line count so totalH is correct when main text wraps (fixes vertical centering).
    local _, mainWrappedLines = titleFont:getWrap(mainText, contentW)
    local mainLineCount = (mainWrappedLines and #mainWrappedLines > 0) and #mainWrappedLines or 1
    local mainBlockH = mainLineCount * titleH
    local totalH = mainBlockH + (subText and subText ~= "" and (GAP + subH) or 0)

    local blockTopY = (screenHeight - totalH) / 2
    love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
    love.graphics.setFont(titleFont)
    love.graphics.printf(mainText, PAD, blockTopY, contentW, "center")

    if subText and subText ~= "" then
        love.graphics.setFont(subFont)
        love.graphics.printf(subText, PAD, blockTopY + mainBlockH + GAP, contentW, "center")
    end
end

return M
