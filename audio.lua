-- audio.lua
-- Minimal audio layer: two global volumes (SFX / music) that the Settings ->
-- Other rows control, plus tiny helpers to play sounds and a looping music
-- track. Missing files are tolerated (logged, never crash), so the template
-- runs with no assets at all.
--
-- USAGE
--   audio.playSFX("sounds/jump.ogg")       -- one-shot, cached after first load
--   audio.playMusic("music/theme.ogg")     -- loops; replaces current track
--   audio.stopMusic()

local debuglog = require("debuglog")

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

function audio.playSFX(path, volumeScale)
    local src = sfxCache[path]
    if src == nil then
        local ok, loaded = pcall(love.audio.newSource, path, "static")
        if ok then
            src = loaded
        else
            debuglog.log("audio: could not load sfx '%s'", path)
            src = false
        end
        sfxCache[path] = src
    end
    if not src then return end
    local instance = src:clone() -- clone so overlapping plays don't cut each other off
    instance:setVolume(audio.globalSFXVolume * (volumeScale or 1))
    instance:play()
end

function audio.playMusic(path)
    audio.stopMusic()
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok then
        debuglog.log("audio: could not load music '%s'", path)
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
