-- src/ui/palette.lua
-- Game Boy style palettes (RGB 0–1 for love.graphics)
-- Supports multiple themes: classic green, red, blue, etc.

local M = {}

-- Theme definitions: each has 4 shades from darkest to lightest
local THEMES = {
    classic = {
        name = "Classic Green",
        -- Original Game Boy (DMG) palette: #0f380f, #306230, #8bac0f, #9bbc0f
        darkest = { 15 / 255, 56 / 255, 15 / 255 },
        dark = { 48 / 255, 98 / 255, 48 / 255 },
        light = { 139 / 255, 172 / 255, 15 / 255 },
        lightest = { 155 / 255, 188 / 255, 15 / 255 },
    },
    red = {
        name = "Virtual Boy Red",
        -- Red monochrome inspired by Virtual Boy
        darkest = { 56 / 255, 8 / 255, 8 / 255 },
        dark = { 120 / 255, 32 / 255, 32 / 255 },
        light = { 200 / 255, 80 / 255, 80 / 255 },
        lightest = { 255 / 255, 120 / 255, 120 / 255 },
    },
    blue = {
        name = "Game Boy Pocket Blue",
        -- Blue tint palette
        darkest = { 8 / 255, 24 / 255, 56 / 255 },
        dark = { 32 / 255, 64 / 255, 120 / 255 },
        light = { 80 / 255, 140 / 255, 200 / 255 },
        lightest = { 120 / 255, 180 / 255, 255 / 255 },
    },
    grayscale = {
        name = "Classic Grayscale",
        -- Black and white Game Boy Pocket style
        darkest = { 0 / 255, 0 / 255, 0 / 255 },
        dark = { 85 / 255, 85 / 255, 85 / 255 },
        light = { 170 / 255, 170 / 255, 170 / 255 },
        lightest = { 255 / 255, 255 / 255, 255 / 255 },
    },
}

-- Theme order for cycling through with toggle
M.THEME_ORDER = { "classic", "red", "blue", "grayscale" }

-- Current active theme (set by setTheme)
M.currentThemeId = "classic"

-- Active palette colors (updated by setTheme)
M.darkestR, M.darkestG, M.darkestB = 15 / 255, 56 / 255, 15 / 255
M.darkR, M.darkG, M.darkB = 48 / 255, 98 / 255, 48 / 255
M.lightR, M.lightG, M.lightB = 139 / 255, 172 / 255, 15 / 255
M.lightestR, M.lightestG, M.lightestB = 155 / 255, 188 / 255, 15 / 255

-- Set the active theme by ID
function M.setTheme(themeId)
    local theme = THEMES[themeId]
    if not theme then
        themeId = "classic"
        theme = THEMES.classic
    end
    M.currentThemeId = themeId
    M.darkestR, M.darkestG, M.darkestB = theme.darkest[1], theme.darkest[2], theme.darkest[3]
    M.darkR, M.darkG, M.darkB = theme.dark[1], theme.dark[2], theme.dark[3]
    M.lightR, M.lightG, M.lightB = theme.light[1], theme.light[2], theme.light[3]
    M.lightestR, M.lightestG, M.lightestB = theme.lightest[1], theme.lightest[2], theme.lightest[3]
end

-- Get the display name of the current theme
function M.getCurrentThemeName()
    local theme = THEMES[M.currentThemeId]
    return theme and theme.name or "Unknown"
end

-- Cycle to the next theme in the order
function M.nextTheme()
    local currentIndex = 1
    for i, id in ipairs(M.THEME_ORDER) do
        if id == M.currentThemeId then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #M.THEME_ORDER) + 1
    return M.THEME_ORDER[nextIndex]
end

return M
