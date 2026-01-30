-- src/ui/loading.lua
-- Loading screen (STATE_LOADING). Matches dashboard client page: overlay style (bg-gameboy-darkest/90,
-- text-gameboy-lightest), p-12, centered "Loading..." with animated ellipsis (dots cycling . / .. / ...).

local design = require("src.ui.design")

local M = {}

local PAD = design.P12

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local p = design.p

    -- Full-screen overlay: bg-gameboy-darkest/90 (same as drag overlay)
    love.graphics.setColor(p.darkestR, p.darkestG, p.darkestB, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Content: p-12, centered. Text in lightest (text-5xl = title font).
    local font = state.titleFont or state.codeFont
    local base = state.loadingMessage or "Loading"
    -- Animate ellipsis: dots cycling . / .. / ... (motion to the dots, typing over and over again)
    local t = love.timer and love.timer.getTime() or 0
    local phase = (t * 2) % 1
    local dots = phase < 0.25 and "." or (phase < 0.5 and ".." or (phase < 0.75 and "..." or ".."))
    local msg = base .. dots

    local _, _, contentW = design.contentBox(screenWidth, screenHeight, PAD)
    local lineH = font:getHeight()
    local blockTopY = (screenHeight - lineH) / 2
    love.graphics.setFont(font)
    love.graphics.setColor(p.lightestR, p.lightestG, p.lightestB)
    love.graphics.printf(msg, PAD, blockTopY, contentW, "center")
end

return M
