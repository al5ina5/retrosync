-- src/assets.lua
-- Load fonts and sounds into state. Safe load for optional assets.
-- Uses love.graphics, love.audio. Call from love.load.
-- Music: tiny Zelda-inspired sleepy 8-bit track; UI: subtle menu sounds.

local M = {}
local audio = require("src.audio")

function M.safeLoadSource(path, kind)
    local ok, result = pcall(function()
        return love.audio.newSource(path, kind or "static")
    end)
    if not ok then
        print("WARN: Failed to load sound " .. tostring(path) .. ": " .. tostring(result))
        return nil
    end
    return result
end

function M.load(state)
    -- Early GameBoy (same family as dashboard: db.onlinewebfonts.com/.../3ada9815c06d2619d52d16a5601c96b2); fallback Minecraft
    local fontPath = "assets/early-gameboy.ttf"
    local fallbackPath = "assets/Minecraft.ttf"
    local ok, err = pcall(function()
        state.titleFont = love.graphics.newFont(fontPath, 48)
        state.codeFont = love.graphics.newFont(fontPath, 32)
        state.largeCountFont = love.graphics.newFont(fontPath, 96)
        state.deviceFont = love.graphics.newFont(fontPath, 24)
        state.smallFont = love.graphics.newFont(fontPath, 12)  -- tiny path line on drag overlay
        -- Home screen 1:1 with dashboard: text-4xl=36px, base=16px (space-y-12=48px, space-y-2=8px, p-6=24px)
        state.homeTitleFont = love.graphics.newFont(fontPath, 36)
        state.homeMenuFont = love.graphics.newFont(fontPath, 16)
    end)
    if not ok then
        ok, err = pcall(function()
            state.titleFont = love.graphics.newFont(fallbackPath, 48)
            state.codeFont = love.graphics.newFont(fallbackPath, 32)
            state.largeCountFont = love.graphics.newFont(fallbackPath, 96)
            state.deviceFont = love.graphics.newFont(fallbackPath, 24)
            state.smallFont = love.graphics.newFont(fallbackPath, 12)
            state.homeTitleFont = love.graphics.newFont(fallbackPath, 36)
            state.homeMenuFont = love.graphics.newFont(fallbackPath, 16)
        end)
    end
    if not ok then
        print("ERROR: Failed to load font: " .. tostring(err))
        state.titleFont = love.graphics.newFont(48)
        state.codeFont = love.graphics.newFont(32)
        state.largeCountFont = love.graphics.newFont(96)
        state.deviceFont = love.graphics.newFont(24)
        state.smallFont = love.graphics.newFont(12)
        state.homeTitleFont = love.graphics.newFont(36)
        state.homeMenuFont = love.graphics.newFont(16)
    end

    -- Music: try sleepy/tunnel OGG first, then procedural Zelda-style lullaby
    state.bgMusic = M.safeLoadSource("assets/music_sleepy.ogg", "stream")
        or M.safeLoadSource("assets/music_tunnel.ogg", "stream")
        or audio.generateSleepyMusic()
    if state.bgMusic then
        state.bgMusic:setLooping(true)
        state.bgMusic:setVolume(0.20)
        if state.musicEnabled then state.bgMusic:play() end
    end
    -- UI: try WAV files first, then subtle procedural blips
    state.uiHoverSound = M.safeLoadSource("assets/ui_hover.wav", "static") or audio.generateUiHover()
    if state.uiHoverSound then state.uiHoverSound:setVolume(0.30) end
    state.uiSelectSound = M.safeLoadSource("assets/ui_select.wav", "static") or audio.generateUiSelect()
    if state.uiSelectSound then state.uiSelectSound:setVolume(0.32) end
    state.uiBackSound = M.safeLoadSource("assets/ui_back.wav", "static") or audio.generateUiBack()
    if state.uiBackSound then state.uiBackSound:setVolume(0.30) end
    state.uiStartSyncSound = M.safeLoadSource("assets/ui_start_sync.wav", "static") or audio.generateUiStartSync()
    if state.uiStartSyncSound then state.uiStartSyncSound:setVolume(0.36) end
end

return M
