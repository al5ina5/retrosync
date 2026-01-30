-- src/audio.lua
-- Procedural 8-bit Zelda-inspired sleepy music and subtle menu sounds.
-- Used when asset files are missing; keeps the app feeling complete and polished.

local M = {}

local RATE = 44100
local BITS = 16
local CHANNELS = 2

-- Soft triangle wave (smooth 8-bit): period in samples, phase 0..1
local function triangle(phase)
    if phase < 0.25 then return phase * 4
    elseif phase < 0.75 then return 2 - phase * 4
    else return phase * 4 - 4
    end
end

-- Gentle sine for bass and smoothness
local function sine(phase)
    return math.sin(phase * 2 * math.pi)
end

-- Zelda-style lullaby: tiny, extremely smooth, makes you want to fall asleep.
-- A minor pentatonic, slow tempo, sparse melody, soft triangle + sine.
function M.generateSleepyMusic()
    local ok, source = pcall(function()
        -- 70 BPM: 16 beats = 4 bars, seamless loop
        local beatDur = 60 / 70
        local duration = 16 * beatDur
        local totalSamples = math.floor(duration * RATE * CHANNELS)
        local soundData = love.sound.newSoundData(totalSamples, RATE, BITS, CHANNELS)
        local frames = math.floor(duration * RATE)

        -- Melody: (time in beats, freq Hz, duration in beats) — Zelda-style, sparse, dreamy
        local melody = {
            { 0,    261.63, 2 },   -- C4
            { 2,    329.63, 2 },   -- E4
            { 4,    392.00, 2 },   -- G4
            { 6,    329.63, 2 },   -- E4
            { 8,    261.63, 2 },   -- C4
            { 10,   220.00, 2 },   -- A3
            { 12,   293.66, 2 },   -- D4
            { 14,   261.63, 2 },   -- C4 (resolve) — loop back to 0
        }
        -- Bass: root every 2 beats, very soft
        local bassNotes = {}
        for b = 0, 16, 2 do bassNotes[#bassNotes + 1] = { b, 110.00, 2 } end -- A2

        local function getMelodySample(tSec)
            local tBeats = tSec / beatDur
            local out = 0
            for _, note in ipairs(melody) do
                local start = note[1] * beatDur
                local freq = note[2]
                local len = note[3] * beatDur
                if tSec >= start and tSec < start + len then
                    local phase = (tSec - start) * freq
                    phase = phase - math.floor(phase)
                    out = out + triangle(phase) * 0.12
                    break
                end
            end
            return out
        end

        local function getBassSample(tSec)
            local tBeats = tSec / beatDur
            for _, note in ipairs(bassNotes) do
                local start = note[1] * beatDur
                local freq = note[2]
                local len = note[3] * beatDur
                if tSec >= start and tSec < start + len then
                    local phase = (tSec - start) * freq
                    return sine(phase - math.floor(phase)) * 0.08
                end
            end
            return 0
        end

        local fadeFrames = math.min(math.floor(0.15 * RATE), frames) -- 150ms fade-in
        for i = 0, frames - 1 do
            local t = i / RATE
            local s = getMelodySample(t) + getBassSample(t)
            if i < fadeFrames and fadeFrames > 0 then
                s = s * (i / fadeFrames)
            end
            s = math.max(-1, math.min(1, s))
            soundData:setSample(i, 1, s)
            soundData:setSample(i, 2, s)
        end

        local src = love.audio.newSource(soundData, "static")
        src:setLooping(true)
        src:setVolume(0.18)
        return src
    end)
    if not ok or not source then return nil end
    return source
end

-- Short, subtle UI blip (duration seconds, frequency Hz, volume 0..1)
local function blip(duration, freq, volume)
    local frames = math.floor(duration * RATE)
    local totalSamples = frames * CHANNELS
    local soundData = love.sound.newSoundData(totalSamples, RATE, BITS, CHANNELS)
    for i = 0, frames - 1 do
        local t = i / RATE
        -- Soft envelope: quick attack, gentle decay so it doesn't click
        local env = math.exp(-t * 8)
        local phase = t * freq
        phase = phase - math.floor(phase)
        local s = sine(phase) * env * volume
        s = math.max(-1, math.min(1, s))
        soundData:setSample(i, 1, s)
        soundData:setSample(i, 2, s)
    end
    return love.audio.newSource(soundData, "static")
end

function M.generateUiHover()
    local ok, src = pcall(function()
        return blip(0.06, 880, 0.22)
    end)
    return ok and src or nil
end

function M.generateUiSelect()
    local ok, src = pcall(function()
        return blip(0.08, 660, 0.26)
    end)
    return ok and src or nil
end

function M.generateUiBack()
    local ok, src = pcall(function()
        return blip(0.06, 440, 0.22)
    end)
    return ok and src or nil
end

function M.generateUiStartSync()
    local ok, src = pcall(function()
        -- Slightly longer, gentle "rise" (two soft notes)
        local duration = 0.14
        local frames = math.floor(duration * RATE)
        local soundData = love.sound.newSoundData(frames * CHANNELS, RATE, BITS, CHANNELS)
        for i = 0, frames - 1 do
            local t = i / RATE
            local env = math.exp(-t * 6)
            local f = 440 + t * 200
            local phase = (i / RATE) * f
            phase = phase - math.floor(phase)
            local s = sine(phase) * env * 0.28
            s = math.max(-1, math.min(1, s))
            soundData:setSample(i, 1, s)
            soundData:setSample(i, 2, s)
        end
        local s = love.audio.newSource(soundData, "static")
        s:setVolume(0.32)
        return s
    end)
    return ok and src or nil
end

return M
