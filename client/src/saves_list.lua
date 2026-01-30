-- src/saves_list.lua
-- Fetch saves list from API and show Recent screen. getFileMtimeSeconds optional (from fs or main).
-- Depends: state, config, http, log, json

local state = require("src.state")
local config = require("src.config")
local http = require("src.http")
local log = require("src.log")
local json = require("lib.dkjson")

local M = {}

local MTIME_TOLERANCE_MS = 10 * 60 * 1000  -- 10 minutes

function M.fetchSavesList(getFileMtimeSeconds)
    log.logMessage("=== fetchSavesList START ===")
    if not state.apiKey then
        log.logMessage("fetchSavesList: No API key, cannot fetch saves")
        state.filesListError = "Not authenticated"
        state.filesListLoading = false
        return
    end
    state.filesListLoading = true
    state.filesListError = ""
    local headers = {["X-API-Key"] = state.apiKey}
    local resp = http.httpGet(state.serverUrl .. "/api/saves", headers)
    if resp and resp ~= "" then
        local result, pos, err = json.decode(resp, 1, nil)
        if err then
            state.filesListError = "Invalid response"
            state.filesListLoading = false
            return
        end
        if result and result.success and result.data then
            local rawSaves = result.data.saves or {}
            local currentDeviceId = nil
            local manifestBySaveId = {}
            local manifestResp = http.httpGet(state.serverUrl .. "/api/sync/manifest", headers)
            if manifestResp and manifestResp ~= "" then
                local manResult, manPos, manErr = json.decode(manifestResp, 1, nil)
                if manResult and manResult.success and manResult.data then
                    currentDeviceId = manResult.data.device and manResult.data.device.id or nil
                    local manifest = manResult.data.manifest or {}
                    for _, item in ipairs(manifest) do
                        if item and item.saveId then
                            manifestBySaveId[item.saveId] = item
                        end
                    end
                end
            end
            state.savesList = {}
            local GREEN = {0.2, 0.9, 0.3}
            local YELLOW = {0.95, 0.85, 0.25}
            local BLUE = {0.4, 0.6, 1.0}
            for _, save in ipairs(rawSaves) do
                local name = save.displayName or save.saveKey or "Unknown"
                local syncedDevices = {}
                if save.locations then
                    for _, loc in ipairs(save.locations) do
                        table.insert(syncedDevices, loc.deviceName or loc.deviceType or "Device")
                    end
                end
                local syncedOnSummary = nil
                if #syncedDevices > 0 then
                    local seenNames = {}
                    local unique = {}
                    for _, dname in ipairs(syncedDevices) do
                        if not seenNames[dname] then
                            seenNames[dname] = true
                            table.insert(unique, dname)
                        end
                    end
                    syncedOnSummary = table.concat(unique, ", ")
                end
                local status = "NOT ON THIS DEVICE"
                local statusColor = YELLOW
                local pendingDir = nil
                local deviceLocalPath = nil
                if currentDeviceId and save.locations then
                    for _, loc in ipairs(save.locations) do
                        if loc.deviceId == currentDeviceId then
                            deviceLocalPath = loc.localPath
                            local strategy = save.syncStrategy or "shared"
                            if strategy == "shared" then
                                status = "SYNCED"
                                statusColor = GREEN
                            else
                                status = "PER DEVICE"
                                statusColor = YELLOW
                            end
                            break
                        end
                    end
                end
                if currentDeviceId and save.id and deviceLocalPath and getFileMtimeSeconds then
                    local manItem = manifestBySaveId[save.id]
                    local latest = manItem and manItem.latestVersion or nil
                    local cloudMs = latest and tonumber(latest.localModifiedAtMs or latest.uploadedAtMs) or nil
                    local localMtime = getFileMtimeSeconds(deviceLocalPath)
                    local localMs = localMtime and (localMtime * 1000) or nil
                    if localMs and cloudMs then
                        if localMs > cloudMs + MTIME_TOLERANCE_MS then pendingDir = "UP"
                        elseif cloudMs > localMs + MTIME_TOLERANCE_MS then pendingDir = "DOWN" end
                    elseif localMs and not cloudMs then
                        pendingDir = "UP"
                    end
                end
                if currentDeviceId and status == "NOT ON THIS DEVICE" and save.id and manifestBySaveId[save.id] then
                    status = "SYNCED"
                    statusColor = GREEN
                end
                if pendingDir == "UP" then
                    status = "PENDING ↑ (UP)"
                    statusColor = BLUE
                elseif pendingDir == "DOWN" then
                    status = "PENDING ↓ (DOWN)"
                    statusColor = BLUE
                end
                table.insert(state.savesList, {
                    name = name,
                    status = status,
                    statusColor = statusColor,
                    syncedOn = syncedOnSummary,
                })
            end
            state.filesListError = ""
        else
            state.filesListError = result and (result.message or result.error or "Failed to fetch saves") or "Unknown error"
            state.savesList = {}
        end
    else
        state.filesListError = "Connection failed"
        state.savesList = {}
    end
    state.filesListLoading = false
    log.logMessage("=== fetchSavesList END ===")
end

function M.showFilesList()
    log.logMessage("=== showFilesList CALLED ===")
    state.filesListScroll = 0
    state.filesListSelectedIndex = 1
    state.savesList = {}
    state.filesListError = ""
    state.filesListLoading = true
    state.currentState = config.STATE_SHOWING_FILES
    state.filesListPending = true
end

return M
