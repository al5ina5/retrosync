-- src/upload.lua
-- Upload saves: discover files, build queue, upload one file. Triggers download phase when done.
-- Depends: config, state, http, log, json, fs, device_history, download

local config = require("src.config")
local state = require("src.state")
local http = require("src.http")
local log = require("src.log")
local json = require("lib.dkjson")
local fs = require("src.fs")
local device_history = require("src.device_history")
local download = require("src.download")

local M = {}

local function uploadSave(filepath)
    if not state.apiKey then
        return false
    end
    if not filepath or filepath == "" then
        return false
    end

    local filename = filepath:match("[/\\]([^/\\]+)$") or filepath

    local fileSize = 0
    local fileContent = nil

    local ok, err = pcall(function()
        local f = io.open(filepath, "rb")
        if not f then
            error("Failed to open file: " .. tostring(filepath))
        end
        f:seek("end")
        fileSize = f:seek()
        if fileSize == 0 then
            f:close()
            error("File is empty")
        end
        f:seek("set", 0)
        fileContent = f:read("*all")
        f:close()
        if not fileContent or #fileContent == 0 then
            error("Failed to read file content or file is empty")
        end
    end)

    if not ok then
        log.logMessage("uploadSave: CRASH reading file: " .. tostring(err))
        return false
    end

    if not fileContent or fileSize == 0 then
        return false
    end

    if fileSize > 10 * 1024 * 1024 then
        log.logMessage("uploadSave: File too large (" .. fileSize .. " bytes), skipping")
        return false
    end

    pcall(function()
        os.execute("mkdir -p '" .. config.WATCHER_DIR:gsub("'", "'\\''") .. "' 2>/dev/null")
    end)

    local base64Content = nil
    local base64Ok, base64Err = pcall(function()
        -- Temp files in watcher/ so data dir has only config.json, logs/, watcher/.
        local tempFile = config.WATCHER_DIR .. "/temp_upload_" .. os.time() .. "_" .. math.random(10000) .. ".bin"
        local tempF = io.open(tempFile, "wb")
        if not tempF then
            log.logMessage("uploadSave: Base64 temp file open failed: " .. tostring(tempFile))
            return false
        end
        tempF:write(fileContent)
        tempF:close()
        -- Escape for shell: single-quote wrap and escape single quotes inside.
        local escapedTempFile = tempFile:gsub("'", "'\\''")
        local cmd = "base64 < '" .. escapedTempFile .. "' 2>/dev/null"
        local handle = io.popen(cmd)
        if not handle then
            log.logMessage("uploadSave: Base64 io.popen failed for: " .. tostring(cmd))
            os.execute("rm -f '" .. escapedTempFile .. "' 2>/dev/null")
            return false
        end
        base64Content = handle:read("*all")
        pcall(function() handle:close() end)
        os.execute("rm -f '" .. escapedTempFile .. "' 2>/dev/null")
        if base64Content then
            base64Content = base64Content:gsub("%s+", "")
        end
        if not base64Content or base64Content == "" then
            log.logMessage("uploadSave: Base64 read empty from base64 command")
            return false
        end
        return true
    end)

    if not base64Ok or not base64Content then
        log.logMessage("uploadSave: Base64 encoding failed: " .. tostring(base64Err))
        return false
    end

    local headers = {["X-API-Key"] = state.apiKey}
    local mtimeSec = fs.getFileMtimeSeconds(filepath)
    local mtimeMs = mtimeSec and (mtimeSec * 1000) or nil
    local payload = {
        filePath = filename,
        fileSize = fileSize,
        action = "upload",
        fileContent = base64Content,
        localPath = filepath,
        localModifiedAt = mtimeMs
    }

    local jsonOk, jsonData, jsonErr = pcall(function()
        return json.encode(payload)
    end)
    if not jsonOk or not jsonData then
        log.logMessage("uploadSave: JSON encode error: " .. tostring(jsonErr or "unknown"))
        return false
    end

    if #jsonData > 50 * 1024 * 1024 then
        log.logMessage("uploadSave: JSON payload too large (" .. #jsonData .. " bytes)")
        return false
    end

    local resp = http.httpPost(state.serverUrl .. "/api/sync/files", jsonData, headers)

    if resp then
        local result, pos, err = json.decode(resp, 1, nil)
        if err then result = nil end
        if result and result.success then
            local data = result.data or result
            if data.skipped then
                return "skipped"
            end
            device_history.addEntry(state, "upload", filename, filepath, fileSize, os.time())
            return true
        else
            return false
        end
    end
    return false
end

function M.uploadSaves()
    if not state.apiKey then
        log.logMessage("uploadSaves: No API key, cannot upload")
        state.currentState = config.STATE_SHOWING_CODE
        return
    end

    if state.soundsEnabled and state.uiStartSyncSound then
        state.uiStartSyncSound:stop()
        state.uiStartSyncSound:play()
    end

    state.syncSessionHadUpload = false
    state.syncSessionHadDownload = false
    state.downloadSuccess = 0
    state.downloadTotal = 0
    state.downloadCancelled = false
    state.downloadQueue = {}
    state.downloadNextIndex = 1
    state.downloadFailedFiles = {}

    state.currentState = config.STATE_UPLOADING
    state.uploadSuccess = 0
    state.uploadTotal = 0
    state.uploadCancelled = false
    state.uploadProgress = ""
    state.pairingError = ""
    state.uploadPending = true
    state.uploadDiscoverPending = false
    state.uploadInProgress = false
    state.uploadQueue = {}
    state.uploadNextIndex = 1
    state.uploadFailedFiles = {}
    state.uploadJustStarted = true
    state.uploadStartTimer = 0
end

local function getFileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

function M.doUploadDiscover()
    local ok, err = pcall(function()
        local findOk, findResult = pcall(function() return fs.findSaveFiles() end)
        if not findOk then
            log.logMessage("CRASH in findSaveFiles: " .. tostring(findResult))
            error("findSaveFiles crashed: " .. tostring(findResult))
        end
        local saveFiles = findResult
        if not saveFiles then
            state.uploadProgress = "Error finding save files"
            state.uploadJustStarted = false
            state.uploadStartTimer = 0
            state.currentState = config.STATE_CONNECTED
            return
        end
        -- saveFiles count logged by findSaveFiles
        if #saveFiles == 0 then
            state.uploadProgress = "No save files found"
            state.uploadJustStarted = false
            state.uploadStartTimer = 0
            state.currentState = config.STATE_CONNECTED
            return
        end

        local cloudByPath = {}
        local cloudBySaveKey = {}
        local manifest, manErr = download.fetchManifest()
        if manifest then
            for _, item in ipairs(manifest) do
                if item and item.localPath and item.latestVersion then
                    local cloudMs = item.latestVersion.localModifiedAtMs or item.latestVersion.uploadedAtMs or 0
                    local byteSize = item.latestVersion.byteSize or 0
                    local contentHash = item.latestVersion.contentHash or ""
                    local key = item.localPath
                    if not cloudByPath[key] or (cloudMs and cloudMs > (cloudByPath[key].cloudMs or 0)) then
                        cloudByPath[key] = {cloudMs = cloudMs, byteSize = byteSize, contentHash = contentHash}
                    end
                    local norm = fs.normalizePathForMatch(item.localPath)
                    if norm ~= key then
                        if not cloudByPath[norm] or (cloudMs and cloudMs > (cloudByPath[norm].cloudMs or 0)) then
                            cloudByPath[norm] = {cloudMs = cloudMs, byteSize = byteSize, contentHash = contentHash}
                        end
                    end
                    local saveKey = item.saveKey
                    if saveKey and saveKey ~= "" then
                        local entry = {cloudMs = cloudMs, byteSize = byteSize, contentHash = contentHash}
                        for _, k in ipairs({ saveKey, saveKey .. ".sav", saveKey .. ".srm" }) do
                            if not cloudBySaveKey[k] or (cloudMs and cloudMs > (cloudBySaveKey[k].cloudMs or 0)) then
                                cloudBySaveKey[k] = entry
                            end
                        end
                    end
                end
            end
        else
            -- no manifest: will upload all
        end

        state.uploadQueue = {}
        local MTIME_TOLERANCE_MS = config.MTIME_TOLERANCE_MS
        for i = 1, #saveFiles do
            local fpath = saveFiles[i]
            local normPath = fs.normalizePathForMatch(fpath)
            local cloudEntry = cloudByPath[fpath] or cloudByPath[normPath]
            local filename = fpath:match("[^/]+$")
            local saveKeyEntry = cloudBySaveKey[filename] or cloudBySaveKey[fs.normalizeBatterySaveKeyForMatch(filename)]
            local localMtime = fs.getFileMtimeSeconds(fpath)
            local localMs = localMtime and (localMtime * 1000) or nil
            local needUpload = true
            local skipReason = nil

            local isMuosPath = fpath:match("/MUOS/save/file") ~= nil

            if needUpload and cloudEntry and cloudEntry.cloudMs and cloudEntry.cloudMs > 0 and localMs then
                if localMs <= cloudEntry.cloudMs + MTIME_TOLERANCE_MS then
                    needUpload = false
                    skipReason = "already on cloud (path match)"
                end
            end

            if not isMuosPath
                and needUpload
                and saveKeyEntry
                and saveKeyEntry.byteSize
                and saveKeyEntry.byteSize > 0
                and localMs
            then
                local localSize = getFileSize(fpath)
                if localSize and localSize == saveKeyEntry.byteSize then
                    local cloudMs = saveKeyEntry.cloudMs or 0
                    if cloudMs > 0 and localMs > cloudMs + MTIME_TOLERANCE_MS then
                        -- Local clearly newer
                    else
                        needUpload = false
                        skipReason = "already on cloud (same filename+size from different emulator)"
                    end
                end
            end

            if needUpload and not localMs and cloudEntry and cloudEntry.byteSize and cloudEntry.byteSize > 0 then
                local localSize = getFileSize(fpath)
                if localSize and localSize == cloudEntry.byteSize then
                    needUpload = false
                    skipReason = "size match, timestamps unavailable (path match)"
                    -- size match, skip
                end
            end

            if not needUpload then
                -- skip (unchanged)
            else
                table.insert(state.uploadQueue, fpath)
            end
        end
        state.uploadTotal = #state.uploadQueue
        state.uploadSuccess = 0
        state.uploadNextIndex = 1
        state.uploadFailedFiles = {}
        state.uploadInProgress = (#state.uploadQueue > 0)
        log.logMessage("uploadSaves: " .. state.uploadTotal .. " files to upload (of " .. #saveFiles .. " discovered)")
        if state.uploadTotal == 0 then
            state.uploadProgress = "All files already synced"
            state.uploadJustStarted = false
            state.uploadStartTimer = 0
            download.downloadSaves(true)
            return
        end
    end)
    if not ok then
        log.logMessage("CRASH in doUploadDiscover: " .. tostring(err))
        log.logMessage("CRASH stack trace: " .. debug.traceback())
        state.pairingError = "Upload error: " .. tostring(err)
        state.uploadJustStarted = false
        state.uploadStartTimer = 0
        state.currentState = config.STATE_CONNECTED
    end
end

function M.doUploadOneFile()
    if state.uploadCancelled then
        state.uploadInProgress = false
        state.uploadJustStarted = false
        state.uploadStartTimer = 0
        if #state.uploadFailedFiles > 0 then
            log.logMessage("uploadSaves: " .. #state.uploadFailedFiles .. " file(s) failed")
        end
        state.currentState = config.STATE_CONNECTED
        return
    end
    if state.uploadNextIndex > state.uploadTotal then
        state.uploadInProgress = false
        state.uploadJustStarted = false
        state.uploadStartTimer = 0
        if #state.uploadFailedFiles > 0 then
            log.logMessage("uploadSaves: " .. #state.uploadFailedFiles .. " file(s) failed")
        else
            log.logMessage("uploadSaves: " .. state.uploadSuccess .. "/" .. state.uploadTotal .. " uploaded")
        end
        state.syncSessionHadUpload = (state.uploadSuccess > 0)
        download.downloadSaves(true)
        return
    end
    local i = state.uploadNextIndex
    local filepath = state.uploadQueue[i]
    if not filepath or filepath == "" then
        log.logMessage("uploadSaves: Skipping invalid filepath at index " .. i)
        table.insert(state.uploadFailedFiles, {index = i, path = "INVALID", reason = "Empty or nil filepath"})
        state.uploadNextIndex = state.uploadNextIndex + 1
        return
    end
    log.logMessage("uploadSaves: Uploading file " .. i .. "/" .. state.uploadTotal .. ": " .. tostring(filepath))
    local uploadOk, uploadResult = pcall(function() return uploadSave(filepath) end)
    if uploadOk and uploadResult == true then
        state.uploadSuccess = state.uploadSuccess + 1
        log.logMessage("uploadSaves: Successfully uploaded file " .. i .. " (" .. state.uploadSuccess .. "/" .. state.uploadTotal .. ")")
    elseif uploadOk and uploadResult == "skipped" then
        log.logMessage("uploadSaves: Skipped (sync disabled) file " .. i .. " - not counting as fail or success")
    elseif not uploadOk then
        log.logMessage("uploadSaves: CRASH uploading file " .. i .. ": " .. tostring(uploadResult))
        table.insert(state.uploadFailedFiles, {index = i, path = filepath, reason = "CRASH: " .. tostring(uploadResult)})
    else
        log.logMessage("uploadSaves: Upload failed for file " .. i .. ": " .. tostring(uploadResult))
        table.insert(state.uploadFailedFiles, {index = i, path = filepath, reason = "Failed: " .. tostring(uploadResult)})
    end
    state.uploadNextIndex = state.uploadNextIndex + 1
end

return M
