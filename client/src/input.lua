-- src/input.lua
-- Keyboard and gamepad input: menu navigation, actions, cancel.
-- Depends: config (passed), state (passed), log, upload, saves_list, settings.

local log = require("src.log")
local upload = require("src.upload")
local saves_list = require("src.saves_list")
local settings_options = require("src.settings_options")
local api = require("src.api")

local M = {}

-- Buttons that mean "back" on gamepad (device-dependent: B may be reported as b, x, or y)
local function isBackButton(button)
    return button == "b" or button == "back" or button == "select" or button == "x" or button == "y"
end

-- Activate the selected settings option. Plays appropriate sound and runs the action.
-- Used for both keyboard (space/return/left/right) and gamepad (a/dpleft/dpright).
local function activateSettingsOption(state, config, opt)
    if not opt then return end
    if opt.id == "back" then
        if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
    else
        if state.soundsEnabled and state.uiSelectSound then state.uiSelectSound:stop(); state.uiSelectSound:play() end
    end
    local msg = settings_options.runOptionAtIndex(state.settingsSelectedIndex, state, config)
    if msg then state.settingsStatusMessage = msg end
end

function M.handleKeypressed(state, config, key)
    local currentTime = love.timer.getTime()
    if currentTime - state.lastInputTime < config.inputDebounceThreshold then
        log.logMessage("love.keypressed: debounced key=" .. tostring(key))
        return
    end
    state.lastInputTime = currentTime

    log.logMessage("love.keypressed: key=" .. tostring(key) .. ", state=" .. state.currentState)
    if state.currentState == config.STATE_LOADING then
        return
    end
    if state.currentState == config.STATE_CONNECTED then
        if key == "up" then
            local prev = state.homeSelectedIndex
            if state.homeSelectedIndex > 1 then state.homeSelectedIndex = state.homeSelectedIndex - 1 end
            if state.soundsEnabled and state.uiHoverSound and state.homeSelectedIndex ~= prev then
                state.uiHoverSound:stop()
                state.uiHoverSound:play()
            end
        elseif key == "down" then
            local prev = state.homeSelectedIndex
            if state.homeSelectedIndex < 3 then state.homeSelectedIndex = state.homeSelectedIndex + 1 end
            if state.soundsEnabled and state.uiHoverSound and state.homeSelectedIndex ~= prev then
                state.uiHoverSound:stop()
                state.uiHoverSound:play()
            end
        elseif key == "return" or key == "space" or key == "a" or key == "x" then
            if state.soundsEnabled and state.uiSelectSound then
                state.uiSelectSound:stop()
                state.uiSelectSound:play()
            end
            if state.homeSelectedIndex == 1 then
                log.logMessage("love.keypressed: Sync selected from home")
                upload.uploadSaves()
            elseif state.homeSelectedIndex == 2 then
                log.logMessage("love.keypressed: Recent selected from home")
                saves_list.showFilesList()
            elseif state.homeSelectedIndex == 3 then
                log.logMessage("love.keypressed: Settings selected from home")
                state.currentState = config.STATE_SETTINGS
                state.settingsSelectedIndex = 1
                state.settingsStatusMessage = ""
            end
        elseif key == "escape" then
            log.logMessage("love.keypressed: Exit triggered via keyboard")
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            love.event.quit()
        end
    elseif state.currentState == config.STATE_SHOWING_FILES then
        if key == "up" then
            local prev = state.filesListSelectedIndex
            if state.filesListSelectedIndex > 1 then state.filesListSelectedIndex = state.filesListSelectedIndex - 1 end
            if state.soundsEnabled and state.uiHoverSound and state.filesListSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif key == "down" then
            local prev = state.filesListSelectedIndex
            if state.filesListSelectedIndex < #state.savesList then state.filesListSelectedIndex = state.filesListSelectedIndex + 1 end
            if state.soundsEnabled and state.uiHoverSound and state.filesListSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif key == "b" or key == "B" or key == "escape" or key == "x" or key == "y" then
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.currentState = config.STATE_CONNECTED
            state.filesListScroll = 0
            state.filesListSelectedIndex = 1
        end
    elseif state.currentState == config.STATE_SETTINGS then
        if key == "up" then
            local prev = state.settingsSelectedIndex
            if state.settingsSelectedIndex > 1 then state.settingsSelectedIndex = state.settingsSelectedIndex - 1 end
            if state.soundsEnabled and state.uiHoverSound and state.settingsSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif key == "down" then
            local prev = state.settingsSelectedIndex
            if state.settingsSelectedIndex < settings_options.getOptionCount() then state.settingsSelectedIndex = state.settingsSelectedIndex + 1 end
            if state.soundsEnabled and state.uiHoverSound and state.settingsSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif key == "left" or key == "right" then
            local opt = settings_options.getOptionAtIndex(state.settingsSelectedIndex, state)
            if opt and opt.activatableWithArrows then
                log.logMessage("Settings: " .. opt.label .. " (arrows)")
                activateSettingsOption(state, config, opt)
            end
        elseif key == "return" or key == "space" or key == "a" or key == "x" then
            local opt = settings_options.getOptionAtIndex(state.settingsSelectedIndex, state)
            if opt then
                log.logMessage("Settings: " .. opt.label .. " selected")
                activateSettingsOption(state, config, opt)
            end
        elseif key == "b" or key == "B" or key == "escape" then
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.currentState = config.STATE_CONNECTED
            state.settingsStatusMessage = ""
        end
    elseif state.currentState == config.STATE_CONFIRM then
        if state.confirmSelectedIndex < 1 then state.confirmSelectedIndex = 1
        elseif state.confirmSelectedIndex > 2 then state.confirmSelectedIndex = 2 end
        if key == "up" then
            local prev = state.confirmSelectedIndex
            if state.confirmSelectedIndex > 1 then state.confirmSelectedIndex = 1 end
            if state.uiHoverSound and state.confirmSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif key == "down" then
            local prev = state.confirmSelectedIndex
            if state.confirmSelectedIndex < 2 then state.confirmSelectedIndex = 2 end
            if state.uiHoverSound and state.confirmSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif key == "return" or key == "space" or key == "a" or key == "x" then
            if state.confirmSelectedIndex == 1 then
                if state.soundsEnabled and state.uiSelectSound then state.uiSelectSound:stop(); state.uiSelectSound:play() end
                if state.confirmAction == "unpair" then
                    api.doUnpairDevice()
                end
            else
                if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
                state.currentState = state.confirmBackState or config.STATE_SETTINGS
            end
        elseif key == "b" or key == "B" or key == "escape" then
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.currentState = state.confirmBackState or config.STATE_SETTINGS
        end
    elseif state.currentState == config.STATE_UPLOADING or state.currentState == config.STATE_DOWNLOADING or state.currentState == config.STATE_SUCCESS then
        local canExit = (key == "escape" or key == "b" or key == "return" or key == "a" or key == "space" or key == "x")
        local allowBack = (state.currentState == config.STATE_SUCCESS) or not state.uploadJustStarted
        if canExit and allowBack then
            log.logMessage("love.keypressed: Exit triggered via keyboard (state=" .. state.currentState .. ")")
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.uploadCancelled = true
            state.downloadCancelled = true
            state.currentState = config.STATE_CONNECTED
        elseif canExit and state.uploadJustStarted and state.currentState ~= config.STATE_SUCCESS then
            log.logMessage("love.keypressed: Cancel ignored (upload just started, state=" .. state.currentState .. ")")
        end
    end
end

function M.handleGamepadpressed(state, config, joystick, button)
    local currentTime = love.timer.getTime()
    if currentTime - state.lastInputTime < config.inputDebounceThreshold then
        log.logMessage("love.gamepadpressed: debounced button=" .. tostring(button))
        return
    end
    state.lastInputTime = currentTime

    log.logMessage("love.gamepadpressed: button=" .. tostring(button) .. ", state=" .. state.currentState)
    if state.currentState == config.STATE_LOADING then
        return
    end
    if state.currentState == config.STATE_CONNECTED then
        if button == "dpup" then
            local prev = state.homeSelectedIndex
            if state.homeSelectedIndex > 1 then state.homeSelectedIndex = state.homeSelectedIndex - 1 end
            if state.soundsEnabled and state.uiHoverSound and state.homeSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "dpdown" then
            local prev = state.homeSelectedIndex
            if state.homeSelectedIndex < 3 then state.homeSelectedIndex = state.homeSelectedIndex + 1 end
            if state.soundsEnabled and state.uiHoverSound and state.homeSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "a" then
            if state.soundsEnabled and state.uiSelectSound then state.uiSelectSound:stop(); state.uiSelectSound:play() end
            if state.homeSelectedIndex == 1 then
                log.logMessage("love.gamepadpressed: Sync selected from home")
                upload.uploadSaves()
            elseif state.homeSelectedIndex == 2 then
                log.logMessage("love.gamepadpressed: Recent selected from home")
                saves_list.showFilesList()
            elseif state.homeSelectedIndex == 3 then
                log.logMessage("love.gamepadpressed: Settings selected from home")
                state.currentState = config.STATE_SETTINGS
                state.settingsSelectedIndex = 1
                state.settingsStatusMessage = ""
            end
        end
    elseif state.currentState == config.STATE_SHOWING_FILES then
        if button == "dpup" then
            local prev = state.filesListSelectedIndex
            if state.filesListSelectedIndex > 1 then state.filesListSelectedIndex = state.filesListSelectedIndex - 1 end
            if state.soundsEnabled and state.uiHoverSound and state.filesListSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "dpdown" then
            local prev = state.filesListSelectedIndex
            if state.filesListSelectedIndex < #state.savesList then state.filesListSelectedIndex = state.filesListSelectedIndex + 1 end
            if state.soundsEnabled and state.uiHoverSound and state.filesListSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif isBackButton(button) then
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.currentState = config.STATE_CONNECTED
            state.filesListScroll = 0
            state.filesListSelectedIndex = 1
        end
    elseif state.currentState == config.STATE_SETTINGS then
        if button == "dpup" then
            local prev = state.settingsSelectedIndex
            if state.settingsSelectedIndex > 1 then state.settingsSelectedIndex = state.settingsSelectedIndex - 1 end
            if state.soundsEnabled and state.uiHoverSound and state.settingsSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "dpdown" then
            local prev = state.settingsSelectedIndex
            if state.settingsSelectedIndex < settings_options.getOptionCount() then state.settingsSelectedIndex = state.settingsSelectedIndex + 1 end
            if state.soundsEnabled and state.uiHoverSound and state.settingsSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "dpleft" or button == "dpright" then
            local opt = settings_options.getOptionAtIndex(state.settingsSelectedIndex, state)
            if opt and opt.activatableWithArrows then
                log.logMessage("Settings (gamepad): " .. opt.label .. " (arrows)")
                activateSettingsOption(state, config, opt)
            end
        elseif button == "a" then
            local opt = settings_options.getOptionAtIndex(state.settingsSelectedIndex, state)
            if opt then
                log.logMessage("Settings (gamepad): " .. opt.label .. " selected")
                activateSettingsOption(state, config, opt)
            end
        elseif isBackButton(button) then
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.currentState = config.STATE_CONNECTED
            state.settingsStatusMessage = ""
        end
    elseif state.currentState == config.STATE_CONFIRM then
        if state.confirmSelectedIndex < 1 then state.confirmSelectedIndex = 1
        elseif state.confirmSelectedIndex > 2 then state.confirmSelectedIndex = 2 end
        if button == "dpup" then
            local prev = state.confirmSelectedIndex
            if state.confirmSelectedIndex > 1 then state.confirmSelectedIndex = 1 end
            if state.soundsEnabled and state.uiHoverSound and state.confirmSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "dpdown" then
            local prev = state.confirmSelectedIndex
            if state.confirmSelectedIndex < 2 then state.confirmSelectedIndex = 2 end
            if state.soundsEnabled and state.uiHoverSound and state.confirmSelectedIndex ~= prev then
                state.uiHoverSound:stop(); state.uiHoverSound:play()
            end
        elseif button == "a" then
            if state.confirmSelectedIndex == 1 then
                if state.soundsEnabled and state.uiSelectSound then state.uiSelectSound:stop(); state.uiSelectSound:play() end
                if state.confirmAction == "unpair" then
                    api.doUnpairDevice()
                end
            else
                if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
                state.currentState = state.confirmBackState or config.STATE_SETTINGS
            end
        elseif isBackButton(button) then
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.currentState = state.confirmBackState or config.STATE_SETTINGS
        end
    elseif state.currentState == config.STATE_UPLOADING or state.currentState == config.STATE_DOWNLOADING or state.currentState == config.STATE_SUCCESS then
        local backButton = (isBackButton(button) or button == "a")
        local allowBack = (state.currentState == config.STATE_SUCCESS) or not state.uploadJustStarted
        if backButton and allowBack then
            log.logMessage("love.gamepadpressed: Exit triggered via gamepad (state=" .. state.currentState .. ")")
            if state.soundsEnabled and state.uiBackSound then state.uiBackSound:stop(); state.uiBackSound:play() end
            state.uploadCancelled = true
            state.downloadCancelled = true
            state.currentState = config.STATE_CONNECTED
        elseif backButton and state.uploadJustStarted and state.currentState ~= config.STATE_SUCCESS then
            log.logMessage("love.gamepadpressed: Cancel ignored (upload just started, state=" .. state.currentState .. ")")
        end
    end
end

return M
