-- isdropping.lua - Adds love.isdropping(x,y) and love.stoppeddropping() for drag-over detection.
-- From https://github.com/EngineerSmith/isdropping (optional dependency; may fail on some platforms).

local ffi = require("ffi")

ffi.cdef[[
    typedef struct SDL_Window SDL_Window;
    SDL_Window *SDL_GL_GetCurrentWindow(void);
    uint32_t SDL_GetGlobalMouseState(int *x, int *y);
    void SDL_GetWindowPosition(SDL_Window * window, int* x, int* y);
    void SDL_RaiseWindow(SDL_Window * window);
]]

local sdl = (jit and jit.os == "Windows") and ffi.load("sdl2") or ffi.C

local dropping = {
    stop = false,
    primaryButton = 1,
    event = "isdropping",
    eventStopped = "stoppeddropping",
}

if not love.window.focus then
    love.window.focus = function()
        sdl.SDL_RaiseWindow(sdl.SDL_GL_GetCurrentWindow())
    end
end

love.handlers[dropping.event] = function(x, y)
    if love[dropping.event] then return love[dropping.event](x, y) end
end

love.handlers[dropping.eventStopped] = function()
    if love[dropping.eventStopped] then return love[dropping.eventStopped]() end
end

local oldHandleFile = love.handlers["filedropped"]
love.handlers["filedropped"] = function(...)
    dropping.heldoutside = false
    return oldHandleFile(...)
end

local oldHandleDir = love.handlers["directorydropped"]
love.handlers["directorydropped"] = function(...)
    dropping.heldoutside = false
    return oldHandleDir(...)
end

local intX = ffi.new("int[1]")
local intY = ffi.new("int[1]")

local set = function() return intX, intY end
local get = function() return tonumber(intX[0]), tonumber(intY[0]) end

local function isPointInsideRect(px, py, x, y, w, h)
    return px > x and px < x + w and py > y and py < y + h
end

local wasInWindow, heldFromWithin = false, false

dropping.eventUpdate = function()
    if dropping.thisFrame then
        dropping.thisFrame = false
        dropping.heldoutside = not love.window.hasMouseFocus()
    end
    if not dropping.stop and not love.window.isMinimized() then
        local button = sdl.SDL_GetGlobalMouseState(set())
        local mouseX, mouseY = get()
        mouseX, mouseY = mouseX + 1, mouseY + 1
        mouseX, mouseY = mouseX - 1, mouseY - 1

        sdl.SDL_GetWindowPosition(sdl.SDL_GL_GetCurrentWindow(), set())
        local windowX, windowY = get()
        local windowW, windowH = love.window.getMode()

        if isPointInsideRect(mouseX, mouseY, windowX, windowY, windowW, windowH) then
            if not heldFromWithin and dropping.heldoutside then
                wasInWindow = true
                if button == dropping.primaryButton then
                    love.event.push(dropping.event, mouseX - windowX, mouseY - windowY)
                else
                    dropping.heldoutside = false
                end
            elseif button == dropping.primaryButton then
                if love.window.hasMouseFocus() then
                    heldFromWithin = true
                else
                    dropping.heldoutside = true
                    dropping.thisFrame = true
                end
            else
                heldFromWithin = false
                if wasInWindow then
                    love.event.push(dropping.eventStopped)
                    wasInWindow = false
                end
            end
        else
            heldFromWithin = false
            if wasInWindow then
                love.event.push(dropping.eventStopped)
                wasInWindow = false
            end
            if heldFromWithin and button ~= dropping.primaryButton then
                heldFromWithin = false
            end
            if wasInWindow and dropping.heldoutside then
                love.event.push(dropping.eventStopped)
                wasInWindow = false
            end
            dropping.heldoutside = (button == dropping.primaryButton)
        end
    end
end

return dropping
