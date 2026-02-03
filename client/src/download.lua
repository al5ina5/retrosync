-- src/download.lua
-- Download saves from server: manifest, discover queue, download one file.
-- Depends: config, state, http, log, json, fs, device_history

local config = require("src.config")
local state = require("src.state")
local http = require("src.http")
local log = require("src.log")
local json = require("lib.dkjson")
local fs = require("src.fs")
local device_history = require("src.device_history")

local M = {}

function M.fetchManifest()
    if not state.apiKey then return nil, "Not authenticated" end
    local headers = {["X-API-Key"] = state.apiKey}
    local resp = http.httpGet(state.serverUrl .. "/api/sync/manifest", headers)
    if not resp or resp == "" then return nil, "No response" end
    local result, pos, err = json.decode(resp, 1, nil)
    if err then return nil, "Invalid manifest JSON" end
    if not (result and result.success and result.data and result.data.manifest) then
        return nil, (result and (result.message or result.error) or "Manifest error")
    end
    return result.data.manifest, nil
end

local function downloadOne(saveVersionId, outPath, mtimeSec)
    if not state.apiKey then return false, "No API key" end
    if not saveVersionId or saveVersionId == "" then return false, "Missing saveVersionId" end
    if not outPath or outPath == "" then return false, "Missing output path" end

    fs.ensureParentDir(outPath)

    local escapedOutPath = outPath:gsub("'", "'\\''")
    local fileExists = os.execute("test -f '" .. escapedOutPath .. "' 2>/dev/null")
    if fileExists == 0 then
        local bakPath = outPath .. ".bak"
        local escapedBakPath = bakPath:gsub("'", "'\\''")
        log.logMessage("download: Creating backup: " .. tostring(bakPath))
        os.execute("cp '" .. escapedOutPath .. "' '" .. escapedBakPath .. "' 2>/dev/null")
    end

    local tmpfile = config.WATCHER_DIR .. "/tmp_download_" .. os.time() .. "_" .. math.random(10000) .. ".bin"
    tmpfile = tmpfile:gsub("[^%w/%.%-_]", "_")

    local url = state.serverUrl .. "/api/sync/download?saveVersionId=" .. tostring(saveVersionId)
    local cmd = "curl -sS -L -H \"X-API-Key: " .. tostring(state.apiKey) .. "\" \"" .. url .. "\" -o \"" .. tmpfile .. "\""
    local exitCode = os.execute(cmd)
    if exitCode ~= 0 then
        pcall(function() os.execute("rm -f \"" .. tmpfile .. "\" 2>/dev/null") end)
        return false, "curl failed"
    end

    local mvCmd = "mv \"" .. tmpfile .. "\" \"" .. outPath .. "\" 2>/dev/null"
    local mvExit = os.execute(mvCmd)
    if mvExit ~= 0 then
        pcall(function() os.execute("rm -f \"" .. tmpfile .. "\" 2>/dev/null") end)
        return false, "failed to write file"
    end
    if mtimeSec and mtimeSec > 0 then
        fs.setFileMtimeSeconds(outPath, mtimeSec)
    end
    return true, nil
end

function M.downloadSaves(fromUpload)
    log.logMessage("=== downloadSaves CALLED (fromUpload=" .. tostring(fromUpload) .. ") ===")
    if not state.apiKey then
        state.currentState = config.STATE_SHOWING_CODE
        return
    end

    if not fromUpload then
        state.syncSessionHadUpload = false
        state.uploadSuccess = 0
        state.uploadTotal = 0
    end
    state.syncSessionHadDownload = false

    state.currentState = config.STATE_DOWNLOADING
    state.downloadSuccess = 0
    state.downloadTotal = 0
    state.downloadCancelled = false
    state.downloadProgress = ""
    state.pairingError = ""
    state.downloadPending = true
    state.downloadInProgress = false
    state.downloadQueue = {}
    state.downloadNextIndex = 1
    state.downloadFailedFiles = {}
    state.uploadJustStarted = true
    state.uploadStartTimer = 0
end

function M.doDownloadDiscover()
    log.logMessage("=== doDownloadDiscover START ===")
    local ok, err = pcall(function()
        local manifest, manErr = M.fetchManifest()
        if not manifest then
            state.pairingError = "Manifest error: " .. tostring(manErr or "unknown")
            state.currentState = config.STATE_CONNECTED
            return
        end

        state.unmappedSavesCount = 0
        for _, item in ipairs(manifest) do
            if item and item.needsMapping then
                state.unmappedSavesCount = state.unmappedSavesCount + 1
            end
        end

        state.downloadQueue = {}
        for _, item in ipairs(manifest) do
            if item and item.localPath and item.latestVersion and item.latestVersion.id then
                local targetPath = item.localPath

                if targetPath:sub(1, 1) ~= "/" then
                    targetPath = "/" .. targetPath
                    log.logMessage("download: Prepending / to path: " .. tostring(targetPath))
                end

                if targetPath:match("/%.netplay/") then
                    local normalized = targetPath:gsub("/%.netplay/", "/")
                    log.logMessage("download: Normalizing netplay path " .. tostring(targetPath) .. " -> " .. tostring(normalized))
                    targetPath = normalized
                end

                local cloudMs = item.latestVersion.localModifiedAtMs or item.latestVersion.uploadedAtMs or 0
                local cloudSize = item.latestVersion.byteSize or 0
                local localMtime = fs.getFileMtimeSeconds(targetPath)
                local localMs = localMtime and (localMtime * 1000) or nil
                local needDownload = true

                if localMs and cloudMs and cloudMs > 0 and cloudMs <= localMs then
                    needDownload = false
                    log.logMessage("download: SKIP (local newer or equal by time) " .. tostring(targetPath) .. " - not queuing")
                elseif not localMs then
                    local escaped = targetPath:gsub("'", "'\\''")
                    local sizeCmd = "wc -c < '" .. escaped .. "' 2>/dev/null"
                    local h = io.popen(sizeCmd)
                    if h then
                        local out = h:read("*all") or ""
                        pcall(function() h:close() end)
                        local localSize = tonumber(out:match("^%s*(%d+)"))
                        if localSize and cloudSize > 0 and localSize == cloudSize then
                            needDownload = false
                            log.logMessage("download: SKIP (size match, no timestamp) " .. tostring(targetPath) .. " local=" .. localSize .. " cloud=" .. cloudSize)
                        elseif localSize then
                            log.logMessage("download: SIZE MISMATCH " .. tostring(targetPath) .. " local=" .. localSize .. " cloud=" .. cloudSize)
                        end
                    end
                end

                if needDownload then
                    table.insert(state.downloadQueue, {
                        localPath = targetPath,
                        saveVersionId = item.latestVersion.id,
                        cloudMs = cloudMs,
                        displayName = item.displayName or item.localPath
                    })
                end
            end
        end

        state.downloadTotal = #state.downloadQueue
        state.downloadSuccess = 0
        state.downloadNextIndex = 1
        state.downloadFailedFiles = {}

        if state.downloadTotal == 0 then
            state.syncSessionHadDownload = false
            state.downloadSuccess = 0
            state.pairingError = ""
            state.uploadJustStarted = false
            state.currentState = config.STATE_SUCCESS
            return
        end

        state.downloadInProgress = true
    end)

    if not ok then
        log.logMessage("CRASH in doDownloadDiscover: " .. tostring(err))
        state.pairingError = "Download error: " .. tostring(err)
        state.currentState = config.STATE_CONNECTED
    end
    log.logMessage("=== doDownloadDiscover END ===")
end

function M.doDownloadOneFile()
    if state.downloadCancelled then
        state.downloadInProgress = false
        state.currentState = config.STATE_CONNECTED
        return
    end

    if state.downloadNextIndex > state.downloadTotal then
        state.downloadInProgress = false
        state.syncSessionHadDownload = (state.downloadSuccess > 0)
        state.uploadJustStarted = false
        state.currentState = config.STATE_SUCCESS
        return
    end

    local i = state.downloadNextIndex
    local item = state.downloadQueue[i]
    if not item or not item.localPath or not item.saveVersionId then
        table.insert(state.downloadFailedFiles, {index = i, path = "INVALID", reason = "Missing fields"})
        state.downloadNextIndex = state.downloadNextIndex + 1
        return
    end

    local cloudMs = tonumber(item.cloudMs) or 0
    local mtimeSec = (cloudMs and cloudMs > 0) and (cloudMs / 1000) or nil

    log.logMessage("download: GET " .. tostring(item.displayName) .. " -> " .. tostring(item.localPath))
    local ok, reason = downloadOne(item.saveVersionId, item.localPath, mtimeSec)
    if ok then
        state.downloadSuccess = state.downloadSuccess + 1
        device_history.addEntry(state, "download", item.displayName or item.localPath or "Unknown", item.localPath, nil, os.time())
    else
        table.insert(state.downloadFailedFiles, {index = i, path = item.localPath, reason = reason or "failed"})
    end

    state.downloadNextIndex = state.downloadNextIndex + 1
end

return M
