-- src/device_history.lua
-- Device-local sync history (this device only). Load, save, add entry.
-- Depends: config, state, json

local config = require("src.config")
local json = require("lib.dkjson")

local M = {}

local function save(state)
    if not state or not state.deviceHistory then return end
    local trimmed = {}
    for i, entry in ipairs(state.deviceHistory) do
        if i > config.MAX_HISTORY_ENTRIES then break end
        table.insert(trimmed, entry)
    end
    state.deviceHistory = trimmed

    local ok, encoded = pcall(function()
        return json.encode(state.deviceHistory)
    end)
    if not ok or not encoded then
        return
    end
    local file = io.open(config.HISTORY_FILE, "w")
    if file then
        file:write(encoded)
        file:close()
    end
end

function M.load(state)
    state.deviceHistory = {}
    local file = io.open(config.HISTORY_FILE, "r")
    if not file then
        return
    end
    local content = file:read("*all")
    file:close()
    if not content or content == "" then
        return
    end

    local ok, data = pcall(function()
        return json.decode(content)
    end)
    if ok and type(data) == "table" then
        state.deviceHistory = data
    else
        state.deviceHistory = {}
    end
end

function M.addEntry(state, direction, name, path, size, ts)
    if not state then return end
    local entry = {
        direction = direction,
        name = name or "Unknown",
        path = path or "",
        size = size or 0,
        ts = ts or os.time(),
        device = state.deviceName or "Unknown"
    }
    table.insert(state.deviceHistory, 1, entry)
    if #state.deviceHistory > config.MAX_HISTORY_ENTRIES then
        while #state.deviceHistory > config.MAX_HISTORY_ENTRIES do
            table.remove(state.deviceHistory)
        end
    end
    save(state)
end

return M
