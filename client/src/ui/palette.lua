-- src/ui/palette.lua
-- Game Boy (DMG) palette from dashboard globals.css. RGB 0–1 for love.graphics.

local M = {}

-- #0f380f, #306230, #8bac0f, #9bbc0f
M.darkestR, M.darkestG, M.darkestB = 15 / 255, 56 / 255, 15 / 255
M.darkR, M.darkG, M.darkB = 48 / 255, 98 / 255, 48 / 255
M.lightR, M.lightG, M.lightB = 139 / 255, 172 / 255, 15 / 255
M.lightestR, M.lightestG, M.lightestB = 155 / 255, 188 / 255, 15 / 255

return M
