-- src/ui/custom_paths.lua
-- Custom paths panel (STATE_CUSTOM_PATHS). List paths + remove selected. Add paths by drag-drop only (see client/UX.md).

local design = require("src.ui.design")
local scan_paths = require("src.scan_paths")

local M = {}

function M.draw(state, config, ui)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)

    local layout = design.listLayout(screenWidth, screenHeight, state)
    local paths = scan_paths.getCustomPathStrings(state)
    local totalRows = #paths + 1  -- paths + "Go Back"
    local sel = state.customPathsSelectedIndex
    if sel < 1 then state.customPathsSelectedIndex = 1; sel = 1
    elseif sel > totalRows then state.customPathsSelectedIndex = totalRows; sel = totalRows end

    love.graphics.setFont(layout.titleFont)
    love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
    love.graphics.print("Custom paths", layout.contentPadding, layout.contentPadding)

    for i, path in ipairs(paths) do
        local rowY = layout.listTopY + (i - 1) * (layout.rowHeight + layout.gapMenu)
        local display = ui.truncateToWidth(path, layout.maxTextW, layout.menuFont)
        design.drawListRow(rowY, display, (i == sel), layout)
    end
    local backY = layout.listTopY + #paths * (layout.rowHeight + layout.gapMenu)
    design.drawListRow(backY, "Go Back", (sel == totalRows), layout)

    design.finishScreen()
end

return M
