-- src/api.lua
-- Pairing: get code, check status, heartbeat, unpair.
-- Depends: config, state, http, storage, log, json (lib.dkjson)

local config = require("src.config")
local state = require("src.state")
local http = require("src.http")
local storage = require("src.storage")
local log = require("src.log")
local json = require("lib.dkjson")

local M = {}

function M.getCodeFromServer()
    if state.deviceCode then
        log.logMessage("getCodeFromServer: Already have code: " .. state.deviceCode)
        return
    end
    state.pairingError = "Getting code..."
    log.logMessage("=== getCodeFromServer START ===")
    log.logMessage("POST " .. state.serverUrl .. "/api/devices/code")
    local url = state.serverUrl .. "/api/devices/code"
    local data = '{"deviceType":"other"}'
    local resp = http.httpPost(url, data)
    if resp and resp ~= "" then
        log.logMessage("Response received: " .. #resp .. " bytes")
        local result, pos, err = json.decode(resp, 1, nil)
        if err then result = nil end
        if result and result.success and result.data and result.data.code then
            state.deviceCode = string.upper(result.data.code)
            storage.saveCode(state.deviceCode)
            state.pairingError = ""
            log.logMessage("SUCCESS: Code saved: " .. state.deviceCode)
        else
            if not result then
                state.pairingError = "Invalid JSON"
            elseif not result.success then
                state.pairingError = "Error: " .. (result.message or result.error or "unknown")
            elseif not result.data then
                state.pairingError = "No data in response"
            elseif not result.data.code then
                state.pairingError = "No code field"
            else
                state.pairingError = "Failed to get code"
            end
        end
    else
        state.pairingError = "Connection failed"
    end
    log.logMessage("=== getCodeFromServer END ===")
end

function M.checkPairingStatus()
    if not state.deviceCode then
        state.pairingError = "No code - fetching..."
        return
    end
    local url = state.serverUrl .. "/api/devices/status"
    local data = '{"code":"' .. string.upper(state.deviceCode) .. '"}'
    local resp = http.httpPost(url, data)
    if resp and resp ~= "" then
        local result, pos, err = json.decode(resp, 1, nil)
        if err then result = nil end
        if result and result.success and result.data then
            local status = result.data.status
            if status == "paired" then
                if result.data.apiKey then
                    state.apiKey = result.data.apiKey
                    state.deviceName = (result.data.device and result.data.device.name) or "Miyoo Flip"
                    storage.saveApiKey(state.apiKey)
                    storage.saveDeviceName(state.deviceName)
                    state.currentState = config.STATE_CONNECTED
                    state.isPaired = true
                    state.pairingError = ""
                    log.logMessage("SUCCESS: Device paired! API key saved.")
                else
                    state.pairingError = "No API key"
                end
            elseif status == "waiting" then
                state.pairingError = ""
            else
                state.pairingError = result.data.message or result.message or "Waiting..."
            end
        else
            state.pairingError = (result and result.message) or "Invalid response"
        end
    else
        state.pairingError = "No response"
    end
end

function M.sendHeartbeat()
    if not state.apiKey then return end
    local headers = {["X-API-Key"] = state.apiKey}
    http.httpPost(state.serverUrl .. "/api/sync/heartbeat", "{}", headers)
end

function M.doUnpairDevice()
    log.logMessage("doUnpairDevice: Clearing pairing data and returning to code screen")
    state.apiKey = nil
    state.deviceName = nil
    state.deviceCode = nil
    state.isPaired = false
    state.pairingError = ""
    state.homeSelectedIndex = 1
    state.codeIntroTimer = 0
    pcall(function() os.remove(config.API_KEY_FILE) end)
    pcall(function() os.remove(config.DEVICE_NAME_FILE) end)
    pcall(function() os.remove(config.CODE_FILE) end)
    state.currentState = config.STATE_SHOWING_CODE
    M.getCodeFromServer()
end

return M
