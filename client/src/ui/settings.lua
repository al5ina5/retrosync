-- src/ui/settings.lua
-- Settings screen (STATE_SETTINGS). Uses design system and settings_options registry.

local design = require("src.ui.design")
local settings_options = require("src.settings_options")

local M = {}

function M.draw(state, config)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    design.drawScreenWithBorder(screenWidth, screenHeight)

    local layout = design.listLayout(screenWidth, screenHeight, state)
    local options = settings_options.getOptions(state)
    local sel = state.settingsSelectedIndex
    if sel < 1 then state.settingsSelectedIndex = 1; sel = 1
    elseif sel > #options then state.settingsSelectedIndex = #options; sel = #options end

    -- Title: top-left with p-12
    love.graphics.setFont(layout.titleFont)
    love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
    love.graphics.print("Settings", layout.contentPadding, layout.contentPadding)

    -- List: one row per option, left-aligned
    for i, opt in ipairs(options) do
        local rowY = layout.listTopY + (i - 1) * (layout.rowHeight + layout.gapMenu)
        design.drawListRow(rowY, opt.label, (i == sel), layout)
    end

    if state.settingsStatusMessage and state.settingsStatusMessage ~= "" then
        love.graphics.setFont(layout.menuFont)
        love.graphics.setColor(design.p.darkR, design.p.darkG, design.p.darkB)
        local msgY = layout.listTopY + #options * (layout.rowHeight + layout.gapMenu) + design.SPACE_Y_6
        love.graphics.print(state.settingsStatusMessage, layout.textX, msgY)
    end

    design.finishScreen()
end

return M
