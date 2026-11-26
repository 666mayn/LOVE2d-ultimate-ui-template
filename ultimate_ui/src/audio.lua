-- audio.lua
-- Minimal audio layer: two global volumes (SFX / music) that the Settings ->
-- Other rows control, plus tiny helpers to play sounds and a looping music
-- track. Missing files are tolerated (logged, never crash), so the template
-- runs with no assets at all.
--
-- USAGE
--   audio.playSFX("sounds/jump.ogg")       -- one-shot, cached after first load
--                                          -- (returns the playing Source, or nil)
--   audio.getSFXDuration("sounds/jump.ogg") -- length in seconds, or nil if it won't load
--   audio.playMusic("music/theme.ogg")     -- loops; replaces current track
--   audio.stopMusic()
--
-- The menu click / loading-screen sounds are wired up in ui_sounds.lua.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")   -- the library folder (this file lives in src/)
local debuglog = require(ROOT .. ".src.debuglog")

local audio = {
    globalSFXVolume = 0.3,
    globalMusicVolume = 0.4,
}

local sfxCache = {}   -- path -> Source or false (failed to load)
local music = nil     -- current music Source

local function clamp01(v)
    return math.max(0, math.min(1, v or 0))
end

-- Setters used by other_settings.lua (they clamp and apply live).
function audio.setSFXVolume(v)
    audio.globalSFXVolume = clamp01(v)
end

function audio.setMusicVolume(v)
    audio.globalMusicVolume = clamp01(v)
    if music then music:setVolume(audio.globalMusicVolume) end
end

-- Loads (once) and returns the cached static Source for `path`, or nil if the
-- file is missing / can't be decoded (a warning is logged the first time).
local function loadSFX(path)
    local src = sfxCache[path]
    if src == nil then
        local ok, loaded = pcall(love.audio.newSource, path, "static")
        if ok then
            src = loaded
        else
            debuglog.warn("audio: could not load sfx '%s' (missing file?)", path)
            src = false
        end
        sfxCache[path] = src
    end
    return src or nil
end

-- Forgets every cached SFX so changed files are re-read on next use.
function audio.clearSFXCache()
    sfxCache = {}
end

-- Length of a sound in seconds, or nil if it can't be loaded.
function audio.getSFXDuration(path)
    local src = loadSFX(path)
    return src and src:getDuration() or nil
end

-- Plays `path` once at the SFX volume (times the optional volumeScale).
-- Returns the playing Source (so you can :stop() it), or nil if it didn't load.
function audio.playSFX(path, volumeScale)
    local src = loadSFX(path)
    if not src then return nil end
    local instance = src:clone() -- clone so overlapping plays don't cut each other off
    instance:setVolume(audio.globalSFXVolume * (volumeScale or 1))
    instance:play()
    return instance
end

function audio.playMusic(path)
    audio.stopMusic()
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok then
        debuglog.warn("audio: could not load music '%s' (missing file?)", path)
        return
    end
    music = src
    music:setLooping(true)
    music:setVolume(audio.globalMusicVolume)
    music:play()
end

function audio.stopMusic()
    if music then
        music:stop()
        music = nil
    end
end

return audio
