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

    -- Seed defaults if still empty
    if #state.scanPathEntries == 0 then
        for _, e in ipairs(M.getDefaultPathEntries()) do
            table.insert(state.scanPathEntries, { path = e.path, kind = "default" })
        end
        getLog().logMessage("scan_paths.load: seeded " .. #state.scanPathEntries .. " default paths")
    end

    state.scanPathsDirty = true
    M.save(state)
end

-- Write state.scanPathEntries to scan_paths.json and scan_paths_flat.txt.
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

    local flatPath = config.SCAN_PATHS_FLAT_FILE
    local flat = io.open(flatPath, "w")
    if flat then
        for _, e in ipairs(entries) do
            if e and e.path and e.path ~= "" then
                flat:write(e.path .. "\n")
            end
        end
        flat:close()
    end
end

-- Return array of { path, kind } for API/heartbeat (from state.scanPathEntries).
function M.getScanPaths(state)
    return state.scanPathEntries or {}
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

-- Overwrite state.scanPathEntries from server response (array of { path, kind }) and save. Clears dirty.
function M.applyFromServer(state, serverPaths)
    if not serverPaths or type(serverPaths) ~= "table" then return end
    state.scanPathEntries = {}
    local seen = {}
    for _, e in ipairs(serverPaths) do
        if e and type(e.path) == "string" and (e.kind == "default" or e.kind == "custom") then
            local p = normalizePath(e.path)
            if p then
                local key = (e.kind or "custom") .. ":" .. p
                if not seen[key] then
                    seen[key] = true
                    table.insert(state.scanPathEntries, { path = p, kind = e.kind })
                end
            end
        end
    end
    M.save(state)
    state.scanPathsDirty = false
    getLog().logMessage("scan_paths.applyFromServer: applied " .. #state.scanPathEntries .. " paths")
end

return M
