-- src/http.lua
-- HTTP GET/POST via curl. Used by api and other modules.
-- Depends: src.config, src.log

local config = require("src.config")
local log = require("src.log")

local M = {}

function M.httpGet(url, headers)
    local tmpfile = "/tmp/retrosync_resp.txt"
    local headerStr = ""
    if headers then
        for k, v in pairs(headers) do
            headerStr = headerStr .. " -H '" .. k .. ": " .. v .. "'"
        end
    end
    local escapedUrl = url:gsub("'", "'\\''")
    local ok, err = pcall(function()
        os.execute("curl -s -m " .. config.HTTP_GET_TIMEOUT .. (headerStr ~= "" and " " or "") .. headerStr .. " '" .. escapedUrl .. "' > " .. tmpfile .. " 2>/dev/null")
    end)
    if not ok then return nil end

    local file = io.open(tmpfile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        pcall(function() os.execute("rm " .. tmpfile .. " 2>/dev/null") end)
        return content
    end
    return nil
end

function M.httpPost(url, data, headers)
    local tmpfile = config.DATA_DIR .. "/http_resp.txt"
    local postfile = config.DATA_DIR .. "/http_post.txt"
    local errfile = config.DATA_DIR .. "/http_err.txt"

    pcall(function()
        os.execute("mkdir -p '" .. config.DATA_DIR .. "' 2>/dev/null")
    end)

    log.logMessage("httpPost: " .. url)
    log.logMessage("  Data: " .. data:sub(1, 100))

    local f = io.open(postfile, "w")
    if f then
        f:write(data)
        f:close()
    else
        log.logMessage("ERROR: Failed to write post file to " .. postfile)
        return nil
    end

    local headerStr = "-H 'Content-Type: application/json'"
    if headers then
        for k, v in pairs(headers) do
            headerStr = headerStr .. " -H '" .. k .. ": " .. v .. "'"
        end
    end

    local dataSize = #data
    local timeout = 10
    if dataSize > 100000 then
        timeout = 120
        log.logMessage("  Large payload detected (" .. dataSize .. " bytes), using extended timeout: " .. timeout .. "s")
    end

    local escapedUrl = url:gsub("'", "'\\''")
    local exitCodeFile = config.DATA_DIR .. "/curl_exit.txt"
    local cmd = "curl -s -m " .. timeout .. " -X POST " .. headerStr .. " -d @" .. postfile .. " '" .. escapedUrl .. "' > " .. tmpfile .. " 2>" .. errfile .. "; echo $? > " .. exitCodeFile
    log.logMessage("  Command: curl -s -m " .. timeout .. " -X POST ...")
    log.logMessage("  Executing curl command (timeout: " .. timeout .. "s)...")
    local startTime = os.time()
    local ok, err = pcall(function()
        local result = os.execute(cmd)
        return result
    end)
    local endTime = os.time()
    log.logMessage("  Curl command completed in " .. (endTime - startTime) .. " seconds")

    if not ok then
        log.logMessage("ERROR: curl command failed: " .. tostring(err))
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' '" .. exitCodeFile .. "' 2>/dev/null") end)
        return nil
    end

    local errf = io.open(errfile, "r")
    if errf then
        local errContent = errf:read("*all")
        errf:close()
        if errContent and errContent ~= "" then
            log.logMessage("curl stderr: " .. errContent)
        end
    end

    local exitCode = 0
    local exitFile = io.open(exitCodeFile, "r")
    if exitFile then
        local exitStr = exitFile:read("*line")
        exitFile:close()
        if exitStr then
            exitCode = tonumber(exitStr) or 0
        end
        pcall(function() os.remove(exitCodeFile) end)
    end

    if exitCode ~= 0 then
        if exitCode == 28 then
            log.logMessage("ERROR: curl timed out after " .. timeout .. " seconds (exit code 28)")
        else
            log.logMessage("ERROR: curl failed with exit code " .. exitCode)
        end
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' 2>/dev/null") end)
        return nil
    end

    local file = io.open(tmpfile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content then
            content = content:match("^%s*(.-)%s*$")
        end
        if content and content ~= "" then
            log.logMessage("  Response: " .. content:sub(1, 200))
        else
            log.logMessage("  Response: (empty)")
        end
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' 2>/dev/null") end)
        return content
    else
        log.logMessage("ERROR: Failed to read response file: " .. tmpfile)
        pcall(function() os.execute("rm -f '" .. postfile .. "' '" .. tmpfile .. "' '" .. errfile .. "' 2>/dev/null") end)
    end
    return nil
end

return M
