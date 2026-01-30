-- src/ui.lua
-- Main UI: display helpers + draw dispatch to screen modules. Call ui.draw(state, config) from love.draw.

local M = {}

local showing_code = require("src.ui.showing_code")
local connected = require("src.ui.connected")
local showing_files = require("src.ui.showing_files")
local settings = require("src.ui.settings")
local sync = require("src.ui.sync")
local confirm = require("src.ui.confirm")
local loading = require("src.ui.loading")
local drag_overlay = require("src.ui.drag_overlay")

function M.formatFileSize(bytes)
    if not bytes or bytes == 0 then
        return "0 B"
    end
    local kb = bytes / 1024
    if kb < 1 then
        return bytes .. " B"
    end
    local mb = kb / 1024
    if mb < 1 then
        return string.format("%.1f KB", kb)
    end
    local gb = mb / 1024
    if gb < 1 then
        return string.format("%.1f MB", mb)
    end
    return string.format("%.2f GB", gb)
end

function M.truncateToWidth(text, maxWidth, font)
    if not text then return "" end
    if not font or maxWidth <= 0 then return "..." end
    if font:getWidth(text) <= maxWidth then
        return text
    end
    local ellipsis = "..."
    local ellipsisW = font:getWidth(ellipsis)
    if ellipsisW >= maxWidth then
        return ellipsis
    end
    local lo, hi = 0, #text
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        local candidate = text:sub(1, mid) .. ellipsis
        if font:getWidth(candidate) <= maxWidth then
            lo = mid
        else
            hi = mid - 1
        end
    end
    return text:sub(1, lo) .. ellipsis
end

function M.formatHistoryTime(ts)
    if not ts then return "" end
    local now = os.time()
    local diff = now - ts
    if diff < 0 then diff = 0 end
    if diff < 5 then
        return "just now"
    elseif diff < 60 then
        return tostring(diff) .. "s ago"
    elseif diff < 3600 then
        local m = math.floor(diff / 60)
        return tostring(m) .. "m ago"
    elseif diff < 86400 then
        local h = math.floor(diff / 3600)
        return tostring(h) .. "h ago"
    else
        return os.date("%Y-%m-%d %H:%M", ts)
    end
end

function M.normalizePathForCustom(path)
    if not path or path == "" then return nil end
    path = path:match("^%s*(.-)%s*$")
    if path == "" then return nil end
    if path:sub(-1) == "/" then
        path = path:sub(1, -2)
    end
    return path
end

function M.draw(state, config)
    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    if state.currentState == config.STATE_SHOWING_CODE then
        showing_code.draw(state, config)
    elseif state.currentState == config.STATE_CONNECTED then
        connected.draw(state, config)
    elseif state.currentState == config.STATE_SHOWING_FILES then
        showing_files.draw(state, config, M)
    elseif state.currentState == config.STATE_SETTINGS then
        settings.draw(state, config)
    elseif state.currentState == config.STATE_CONFIRM then
        confirm.draw(state, config)
    elseif state.currentState == config.STATE_LOADING then
        loading.draw(state, config)
    elseif state.currentState == config.STATE_UPLOADING or state.currentState == config.STATE_DOWNLOADING or state.currentState == config.STATE_SUCCESS then
        sync.draw(state, config)
    end

    if state.pairingError ~= "" and state.currentState ~= config.STATE_SHOWING_CODE then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.setFont(state.codeFont)
        love.graphics.printf(state.pairingError, 0, 460, screenWidth, "center")
    end

    -- Drag/drop overlay (dashboard client page design: darkest/90, lightest text, p-12 space-y-6)
    drag_overlay.draw(state, config, M)

    if state.pathAddedAt and (love.timer.getTime() - state.pathAddedAt) >= config.PATH_ADDED_DURATION then
        state.pathAddedAt = nil
        state.pathAddedMessage = nil
    end
end

return M
