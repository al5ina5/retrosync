-- src/scan_paths.lua
-- Single source of truth for scan paths: load/save scan_paths.json, default OS paths, sync with server.

local config = require("src.config")
local json = require("lib.dkjson")

local M = {}

-- Returns default path entries for the current OS (suggestions only; actual list lives in file).
function M.getDefaultPathEntries()
    local entries = {}
    local paths = {
        "/mnt/sdcard/Saves/saves",
        "/mnt/mmc/MUOS/save/file",
    }
    local home = os.getenv("HOME")
    if home and home ~= "" then
        table.insert(paths, home .. "/Library/Application Support/OpenEmu")
    end
    for _, p in ipairs(paths) do
        if p and p ~= "" then
            table.insert(entries, { path = p, kind = "default" })
        end
    end
    return entries
end

-- Legacy: raw default path strings (for watcher fallback / migration).
function M.getDefaultPaths()
    local paths = {}
    for _, e in ipairs(M.getDefaultPathEntries()) do
        table.insert(paths, e.path)
    end
    return paths
end

local function getLog()
    return require("src.log")
end

local function normalizePath(path)
    if not path or type(path) ~= "string" then return nil end
    path = path:match("^%s*(.-)%s*$")
    if not path or path == "" then return nil end
    if path:sub(-1) == "/" then path = path:sub(1, -2) end
    return path
end

-- True if path exists and is a directory (used to only add/send matching default paths).
local function pathExists(path)
    if not path or path == "" then return false end
    local escaped = path:gsub("'", "'\\''")
    local cmd = "test -d '" .. escaped .. "' 2>/dev/null && echo 1 || echo 0"
    local h = io.popen(cmd)
    if not h then return false end
    local out = h:read("*all") or ""
    pcall(function() h:close() end)
    return out:match("1") ~= nil
end

-- Load scan_paths.json into state.scanPathEntries. If missing/empty, seed from defaults and save.
-- If legacy custom_paths.txt exists, merge its lines as custom entries then remove reliance on it.
function M.load(state)
    state.scanPathEntries = state.scanPathEntries or {}
    local path = config.SCAN_PATHS_FILE
    local file = io.open(path, "r")
    if file then
        local raw = file:read("*a")
        file:close()
        if raw and raw ~= "" then
            local ok, data = pcall(json.decode, raw)
            if ok and data and type(data.paths) == "table" then
                local seen = {}
                for _, e in ipairs(data.paths) do
                    if e and type(e.path) == "string" and type(e.kind) == "string" then
                        local p = normalizePath(e.path)
                        if p and (e.kind == "default" or e.kind == "custom") then
                            local key = e.kind .. ":" .. p
                            if not seen[key] then
                                seen[key] = true
                                table.insert(state.scanPathEntries, { path = p, kind = e.kind })
                            end
                        end
                    end
                end
                if #state.scanPathEntries > 0 then
                    getLog().logMessage("scan_paths.load: loaded " .. #state.scanPathEntries .. " from " .. path)
                    return
                end
            end
        end
    end

    -- Migrate from legacy custom_paths.txt
    local legacyPath = config.CUSTOM_PATHS_FILE
    local legacy = io.open(legacyPath, "r")
    if legacy then
        for line in legacy:lines() do
            line = line and line:match("^%s*(.-)%s*$") or ""
            if line ~= "" then
                local p = normalizePath(line)
                if p then
                    table.insert(state.scanPathEntries, { path = p, kind = "custom" })
                end
            end
        end
        legacy:close()
        getLog().logMessage("scan_paths.load: migrated " .. #state.scanPathEntries .. " from " .. legacyPath)
    end

    -- Seed defaults if still empty; only add default paths that exist on this device
    if #state.scanPathEntries == 0 then
        for _, e in ipairs(M.getDefaultPathEntries()) do
            if pathExists(e.path) then
                table.insert(state.scanPathEntries, { path = e.path, kind = "default" })
            end
        end
        getLog().logMessage("scan_paths.load: seeded " .. #state.scanPathEntries .. " default paths (matching only)")
    end

    -- Prune default paths that no longer exist so dashboard and file stay accurate
    local list = state.scanPathEntries or {}
    for i = #list, 1, -1 do
        local e = list[i]
        if e and e.kind == "default" and (not e.path or not pathExists(e.path)) then
            table.remove(list, i)
            getLog().logMessage("scan_paths.load: pruned non-existent default path " .. tostring(e.path))
        end
    end

    state.scanPathsDirty = true
    M.save(state)
end

-- Write state.scanPathEntries to scan_paths.json (single source of truth; watcher reads JSON via jq).
function M.save(state)
    local entries = state.scanPathEntries or {}
    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
    end)

    local path = config.SCAN_PATHS_FILE
    local file = io.open(path, "w")
    if file then
        file:write(json.encode({ paths = entries }))
        file:close()
        getLog().logMessage("scan_paths.save: wrote " .. #entries .. " to " .. path)
    end
end

-- Return array of { path, kind } for API/heartbeat.
-- When forApi is true, only include default paths that exist on this device (matching only).
function M.getScanPaths(state, forApi)
    local entries = state.scanPathEntries or {}
    if not forApi then return entries end
    local out = {}
    for _, e in ipairs(entries) do
        if e and e.path and e.path ~= "" then
            if e.kind == "custom" then
                table.insert(out, { path = e.path, kind = e.kind })
            elseif e.kind == "default" and pathExists(e.path) then
                table.insert(out, { path = e.path, kind = e.kind })
            end
        end
    end
    return out
end

-- Return list of path strings for kind == "custom" (for UI).
function M.getCustomPathStrings(state)
    local out = {}
    for _, e in ipairs(state.scanPathEntries or {}) do
        if e.kind == "custom" and e.path and e.path ~= "" then
            table.insert(out, e.path)
        end
    end
    return out
end

-- Add a path; kind is "default" or "custom". Marks dirty. Returns true if added.
function M.addPath(state, path, kind)
    if kind ~= "default" and kind ~= "custom" then kind = "custom" end
    local p = normalizePath(path)
    if not p then return false end
    state.scanPathEntries = state.scanPathEntries or {}
    local key = kind .. ":" .. p
    for _, e in ipairs(state.scanPathEntries) do
        if (e.kind or "custom") .. ":" .. (e.path or "") == key then return false end
    end
    table.insert(state.scanPathEntries, { path = p, kind = kind })
    M.save(state)
    state.scanPathsDirty = true
    getLog().logMessage("scan_paths.addPath: " .. kind .. " " .. p)
    return true
end

-- Remove one entry by path (and optionally kind). Marks dirty. Returns true if removed.
function M.removePath(state, path, kind)
    local p = normalizePath(path)
    if not p then return false end
    local list = state.scanPathEntries or {}
    for i = #list, 1, -1 do
        local e = list[i]
        if e and (e.path or "") == p and (not kind or e.kind == kind) then
            table.remove(list, i)
            M.save(state)
            state.scanPathsDirty = true
            getLog().logMessage("scan_paths.removePath: " .. (e.kind or "?") .. " " .. p)
            return true
        end
    end
    return false
end

-- True if two entry lists have the same set of path+kind (order-independent).
local function entriesEqual(a, b)
    if not a or not b then return (not a or #a == 0) and (not b or #b == 0) end
    if #a ~= #b then return false end
    local set = {}
    for _, e in ipairs(a) do
        if e and e.path and e.kind then
            local key = e.kind .. ":" .. e.path
            set[key] = (set[key] or 0) + 1
        end
    end
    for _, e in ipairs(b) do
        if e and e.path and e.kind then
            local key = e.kind .. ":" .. e.path
            if not set[key] or set[key] == 0 then return false end
            set[key] = set[key] - 1
        end
    end
    return true
end

-- Overwrite state.scanPathEntries from server response (array of { path, kind }) and save. Clears dirty.
-- Only writes to disk when the new list differs from current state (avoids redundant I/O and log noise).
function M.applyFromServer(state, serverPaths)
    if not serverPaths or type(serverPaths) ~= "table" then return end
    state.scanPathEntries = state.scanPathEntries or {}
    local newEntries = {}
    local seen = {}
    for _, e in ipairs(serverPaths) do
        if e and type(e.path) == "string" and (e.kind == "default" or e.kind == "custom") then
            local p = normalizePath(e.path)
            if p then
                local key = (e.kind or "custom") .. ":" .. p
                if not seen[key] then
                    seen[key] = true
                    table.insert(newEntries, { path = p, kind = e.kind })
                end
            end
        end
    end
    if entriesEqual(state.scanPathEntries, newEntries) then
        state.scanPathsDirty = false
        return
    end
    state.scanPathEntries = newEntries
    M.save(state)
    state.scanPathsDirty = false
    getLog().logMessage("scan_paths.applyFromServer: applied " .. #state.scanPathEntries .. " paths")
end

return M
