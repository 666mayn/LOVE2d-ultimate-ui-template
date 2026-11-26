-- intro_sequence.lua
-- Plays .ogv clips back to back on startup, before the main menu shows. Draws to whatever
-- canvas/screen the caller currently has set. Missing or broken clips are skipped; no clips
-- finishes immediately.
--
-- WHICH CLIPS: with `paths` = nil (config.introVideos = nil) every .ogv under intro_clips/ plays,
-- nested folders included, in path order. Swap the intro by replacing the file; add intro2.ogv
-- to chain another. A list of paths plays exactly those; false means no intro.
--
--   intro_sequence.start(config.introVideos, function() ...menu music etc... end)
--   love.update:   intro_sequence.update(dt)
--   love.draw:     if intro_sequence.isActive() then intro_sequence.draw(w, h, uiScale) end
--   any input:     if intro_sequence.isActive() then intro_sequence.skip() end   -- skips the WHOLE intro

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")   -- the library folder (this file lives in src/)
local debuglog = require(ROOT .. ".src.debuglog")
local helpers = require(ROOT .. ".ui.helpers")
local config = require(ROOT .. ".config")

local intro_sequence = {}

local CLIP_DIR = (ROOT:gsub("%.", "/")) .. "/intro_clips"
local MAX_DEPTH = 6
intro_sequence.dir = CLIP_DIR

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

local function scan(dir, depth, out)
    if depth > MAX_DEPTH then return end
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    for _, name in ipairs(items) do
        local path = dir .. "/" .. name
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "directory" then
                scan(path, depth + 1, out)
            elseif info.type == "file" and name:lower():match("%.ogv$") then
                out[#out + 1] = path
            end
        end
    end
end

-- Every .ogv under intro_clips/ (nested folders included), sorted by path.
function intro_sequence.list()
    local out = {}
    if love.filesystem.getInfo(CLIP_DIR, "directory") then scan(CLIP_DIR, 1, out) end
    return out
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
            -- Smooth scaling. Video is a new texture, so it gets the project's DEFAULT filter, which is
            -- "nearest" in Sharp texture mode (Settings -> Textures): a 1080p clip squeezed into a smaller
            -- window then drops pixels and every edge turns to jagged stair-steps. Linear averages them.
            pcall(introVideo.setFilter, introVideo, "linear", "linear")
            introVideo:play()
            return
        end
        debuglog.warn("intro video failed to load (%s): %s", path, tostring(videoOrErr))
        introIndex = introIndex + 1
    end
end

-- Call once from love.load(). `paths` is a list of video file paths and
-- `onFinished` is called once the last clip ends (or is skipped).
function intro_sequence.start(paths, onFinished)
    if paths == nil or (type(paths) == "table" and #paths == 0) then
        paths = intro_sequence.list()   -- nil / empty list = whatever is in intro_clips/
    end
    introVideoPaths = paths or {}                            -- false = no intro
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
-- intro is active: any input ends the whole intro (every remaining clip too).
function intro_sequence.skip()
    if not introActive then return end
    if introVideo then introVideo:pause() end
    introIndex = #introVideoPaths + 1
    loadNextIntro()   -- nothing left, so this just finishes
end

function intro_sequence.update(dt)
    if not introActive then return end
    if introVideo and not introVideo:isPlaying() then
        introIndex = introIndex + 1
        loadNextIntro()
    end
end

-- Draws the current intro clip (native-scaled, letterboxed to fit) on black. The skip hint is
-- off by default (config.introSkipHint = true shows "Press any key to skip").
function intro_sequence.draw(canvasWidth, canvasHeight, uiScale)
    if not introVideo then return end
    local videoWidth, videoHeight = introVideo:getWidth(), introVideo:getHeight()
    local drawX, drawY, scale = computeContainTransform(videoWidth, videoHeight, canvasWidth, canvasHeight)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, canvasWidth, canvasHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(introVideo, drawX, drawY, 0, scale, scale)

    if config.introSkipHint then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(helpers.getFont(18 * uiScale, "hint"))
        love.graphics.printf("Press any key to skip", 0, canvasHeight - 50 * uiScale, canvasWidth, "center")
    end
end

return intro_sequence
