-- src/ui/about.lua
-- About panel (STATE_ABOUT). Read-only: app name, server URL. No typing (see client/UX.md).

local design = require("src.ui.design")

local M = {}

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)

    local layout = design.listLayout(screenWidth, screenHeight, state)
    local p = design.p

    love.graphics.setFont(layout.titleFont)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.print("About", layout.contentPadding, layout.contentPadding)

    local lineY = layout.listTopY
    love.graphics.setFont(layout.menuFont)
    love.graphics.setColor(p.darkR, p.darkG, p.darkB)
    love.graphics.print("RetroSync", layout.textX, lineY)
    lineY = lineY + layout.rowHeight + layout.gapMenu
    local url = state.serverUrl or config.SERVER_URL or ""
    love.graphics.print(url, layout.textX, lineY)
    lineY = lineY + layout.rowHeight + layout.gapMenu * 2

    local sel = state.aboutSelectedIndex
    if sel < 1 then state.aboutSelectedIndex = 1; sel = 1 end
    design.drawListRow(lineY, "Go Back", (sel == 1), layout)

    design.finishScreen()
end

return M
