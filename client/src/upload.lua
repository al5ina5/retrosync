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
    log.logMessage("=== uploadSave START ===")
    log.logMessage("uploadSave: filepath = " .. tostring(filepath))

    if not state.apiKey then
        log.logMessage("uploadSave: No API key, returning false")
        return false
    end
    log.logMessage("uploadSave: API key exists")

    if not filepath or filepath == "" then
        log.logMessage("uploadSave: Invalid filepath")
        return false
    end

    local filename = filepath:match("[/\\]([^/\\]+)$") or filepath
    log.logMessage("uploadSave: filename = " .. tostring(filename))

    local fileSize = 0
    local fileContent = nil

    log.logMessage("uploadSave: Starting file read operation")
    local ok, err = pcall(function()
        log.logMessage("uploadSave: Opening file: " .. tostring(filepath))
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
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)

    local base64Content = nil
    local base64Ok, base64Err = pcall(function()
        local tempFile = config.DATA_DIR .. "/temp_upload_" .. os.time() .. "_" .. math.random(10000) .. ".bin"
        tempFile = tempFile:gsub("[^%w/%.%-_]", "_")
        local tempF = io.open(tempFile, "wb")
        if not tempF then return false end
        tempF:write(fileContent)
        tempF:close()
        local escapedTempFile = tempFile:gsub("'", "'\\''")
        local cmd = "base64 < '" .. escapedTempFile .. "' 2>/dev/null"
        local handle = io.popen(cmd)
        if not handle then
            os.execute("rm -f '" .. escapedTempFile .. "' 2>/dev/null")
            return false
        end
        base64Content = handle:read("*all")
        pcall(function() handle:close() end)
        if base64Content then
            base64Content = base64Content:gsub("%s+", "")
        end
        os.execute("rm -f '" .. escapedTempFile .. "' 2>/dev/null")
        if not base64Content or base64Content == "" then return false end
        return true
    end)

    if not base64Ok or not base64Content then
        log.logMessage("uploadSave: Base64 encoding failed: " .. tostring(base64Err))
        return false
    end

    local headers = {["X-API-Key"] = state.apiKey}
    local mtimeSec = fs.getFileMtimeSeconds(filepath)
    local mtimeMs = mtimeSec and (mtimeSec * 1000) or nil
    if mtimeMs then
        log.logMessage("uploadSave: File mtime: " .. mtimeMs .. " ms (" .. os.date("%Y-%m-%d %H:%M:%S", mtimeSec) .. ")")
    else
        log.logMessage("uploadSave: WARNING - No mtime available, server will use upload time")
    end
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
                log.logMessage("uploadSave: Server skipped upload for " .. filename .. " (unchanged or sync disabled)")
                return "skipped"
            end
            log.logMessage("uploadSave: Successfully uploaded " .. filename)
            device_history.addEntry(state, "upload", filename, filepath, fileSize, os.time())
            return true
        else
            log.logMessage("uploadSave: Server returned error for " .. filename)
            return false
        end
    end
    log.logMessage("uploadSave: No response from server for " .. filename)
    return false
end

function M.uploadSaves()
    log.logMessage("=== uploadSaves CALLED ===")

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
    log.logMessage("uploadSaves: State immediately set to UPLOADING, work deferred (chunked per frame)")
end

local function getFileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

function M.doUploadDiscover()
    log.logMessage("=== doUploadDiscover START ===")
    local ok, err = pcall(function()
        log.logMessage("uploadSaves: Calling findSaveFiles()")
        local findOk, findResult = pcall(function() return fs.findSaveFiles() end)
        if not findOk then
            log.logMessage("CRASH in findSaveFiles: " .. tostring(findResult))
            error("findSaveFiles crashed: " .. tostring(findResult))
        end
        local saveFiles = findResult
        if not saveFiles then
            log.logMessage("uploadSaves: findSaveFiles returned nil")
            state.uploadProgress = "Error finding save files"
            state.uploadJustStarted = false
            state.uploadStartTimer = 0
            state.currentState = config.STATE_CONNECTED
            return
        end
        log.logMessage("uploadSaves: Found " .. #saveFiles .. " save files")
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
            log.logMessage("uploadSaves: No manifest (will upload all): " .. tostring(manErr or "unknown"))
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
                    log.logMessage("uploadSaves: SIZE MATCH (no timestamp) " .. tostring(fpath) .. " local=" .. localSize .. " cloud=" .. cloudEntry.byteSize)
                end
            end

            if not needUpload then
                log.logMessage("uploadSaves: SKIP (" .. (skipReason or "unknown") .. ") " .. tostring(fpath))
            else
                table.insert(state.uploadQueue, fpath)
            end
        end
        state.uploadTotal = #state.uploadQueue
        state.uploadSuccess = 0
        state.uploadNextIndex = 1
        state.uploadFailedFiles = {}
        state.uploadInProgress = (#state.uploadQueue > 0)
        log.logMessage("uploadSaves: Will upload " .. state.uploadTotal .. " files (of " .. #saveFiles .. " discovered)")
        if state.uploadTotal == 0 then
            state.uploadProgress = "All files already synced"
            state.uploadJustStarted = false
            state.uploadStartTimer = 0
            log.logMessage("uploadSaves: Starting download phase (no uploads needed)")
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
    log.logMessage("=== doUploadDiscover END ===")
end

function M.doUploadOneFile()
    log.logMessage("=== doUploadOneFile (index " .. tostring(state.uploadNextIndex) .. ") ===")
    if state.uploadCancelled then
        log.logMessage("uploadSaves: Upload cancelled by user, stopping")
        state.uploadInProgress = false
        state.uploadJustStarted = false
        state.uploadStartTimer = 0
        if #state.uploadFailedFiles > 0 then
            log.logMessage("uploadSaves: FAILED FILES SUMMARY:")
            for _, fail in ipairs(state.uploadFailedFiles) do
                log.logMessage("uploadSaves:   File " .. fail.index .. ": " .. fail.path .. " - " .. fail.reason)
            end
        end
        state.currentState = config.STATE_CONNECTED
        return
    end
    if state.uploadNextIndex > state.uploadTotal then
        log.logMessage("uploadSaves: All files processed")
        state.uploadInProgress = false
        state.uploadJustStarted = false
        state.uploadStartTimer = 0
        if #state.uploadFailedFiles > 0 then
            log.logMessage("uploadSaves: FAILED FILES SUMMARY:")
            for _, fail in ipairs(state.uploadFailedFiles) do
                log.logMessage("uploadSaves:   File " .. fail.index .. ": " .. fail.path .. " - " .. fail.reason)
            end
        else
            log.logMessage("uploadSaves: All files uploaded successfully!")
        end
        log.logMessage("uploadSaves: Complete - " .. state.uploadSuccess .. "/" .. state.uploadTotal .. " files uploaded")
        state.syncSessionHadUpload = (state.uploadSuccess > 0)
        log.logMessage("uploadSaves: Starting download phase after uploads complete")
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
