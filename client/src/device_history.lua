-- src/device_history.lua
-- Device-local sync history (this device only). Load/save via config.json (storage.saveConfig).
-- Depends: config, state, json, storage (for save)

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
    local storage = require("src.storage")
    storage.saveConfig(state)
end

function M.load(state)
    state.deviceHistory = state.deviceHistory or {}
    -- One-time migration: if empty, try legacy device_history.json (storage.loadConfig may have already migrated)
    if #state.deviceHistory == 0 then
        local path = config.DATA_DIR .. "/device_history.json"
        local file = io.open(path, "r")
        if file then
            local content = file:read("*a")
            file:close()
            if content and content ~= "" then
                local ok, data = pcall(json.decode, content)
                if ok and type(data) == "table" then
                    state.deviceHistory = data
                    local storage = require("src.storage")
                    storage.saveConfig(state)
                end
            end
            pcall(function() os.remove(path) end)
        end
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
