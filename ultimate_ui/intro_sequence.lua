-- intro_sequence.lua
-- Plays a list of .ogv clips back to back on startup, before the main menu
-- shows. Draws to whatever canvas/screen the caller currently has set.
-- Missing or broken clips are skipped; an empty list finishes immediately.
--
--   intro_sequence.start(config.introVideos, function() ...menu music etc... end)
--   love.update:   intro_sequence.update(dt)
--   love.draw:     if intro_sequence.isActive() then intro_sequence.draw(w, h, uiScale) end
--   any input:     if intro_sequence.isActive() then intro_sequence.skip() end

local ROOT = (...):match("^(.*)%.[^.]+$")
local debuglog = require(ROOT .. ".debuglog")
local helpers = require(ROOT .. ".ui.helpers")

local intro_sequence = {}

local introVideoPaths = {}
local introIndex = 1
local introVideo = nil
local introActive = false
local onDone = nil

-- Scales/centers a video to fill the canvas while preserving its native
-- aspect ratio (letterboxed rather than stretched/distorted).
local function computeContainTransform(videoWidth, videoHeight, canvasWidth, canvasHeight)
    local scale = math.min(canvasWidth / videoWidth, canvasHeight / videoHeight)
    local drawWidth, drawHeight = videoWidth * scale, videoHeight * scale
    local drawX = (canvasWidth - drawWidth) / 2
    local drawY = (canvasHeight - drawHeight) / 2
    return drawX, drawY, scale
end

local function finish()
    introActive = false
    introVideo = nil
    if onDone then
        local cb = onDone
        onDone = nil
        cb()
    end
end

local function loadNextIntro()
    while true do
        if introIndex > #introVideoPaths then
            finish()
            return
        end
        local path = introVideoPaths[introIndex]
        local ok, videoOrErr = pcall(love.graphics.newVideo, path)
        if ok then
            introVideo = videoOrErr
            introVideo:play()
            return
        end
        debuglog.log("Intro video failed to load (%s): %s", path, tostring(videoOrErr))
        introIndex = introIndex + 1
    end
end

-- Call once from love.load(). `paths` is a list of video file paths and
-- `onFinished` is called once the last clip ends (or is skipped).
function intro_sequence.start(paths, onFinished)
    introVideoPaths = paths or {}
    introIndex = 1
    introVideo = nil
    onDone = onFinished
    introActive = true
    loadNextIntro()
end

function intro_sequence.isActive()
    return introActive
end

-- Called from every input callback (mouse/keyboard/gamepad) while an
-- intro is active, so any input advances/skips the current clip.
function intro_sequence.skip()
    if not introActive then return end
    if introVideo then introVideo:pause() end
    introIndex = introIndex + 1
    loadNextIntro()
end

function intro_sequence.update(dt)
    if not introActive then return end
    if introVideo and not introVideo:isPlaying() then
        introIndex = introIndex + 1
        loadNextIntro()
    end
end

-- Draws the current intro clip (native-scaled, letterboxed to fit) plus a
-- skip hint, styled like the rest of the UI.
function intro_sequence.draw(canvasWidth, canvasHeight, uiScale)
    if not introVideo then return end
    local videoWidth, videoHeight = introVideo:getWidth(), introVideo:getHeight()
    local drawX, drawY, scale = computeContainTransform(videoWidth, videoHeight, canvasWidth, canvasHeight)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(introVideo, drawX, drawY, 0, scale, scale)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(helpers.getFont(18 * uiScale))
    love.graphics.printf("Press any key to skip", 0, canvasHeight - 50 * uiScale, canvasWidth, "center")
end

return intro_sequence
