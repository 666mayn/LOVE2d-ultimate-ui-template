-- ui_sounds.lua
-- The three built-in sounds of the template, wired to the menus:
--
--     intro    played over the startup intro video; cut off when the intro ends or is skipped
--              (a click / key press during the intro plays the ui sound instead)
--     ui       played whenever a menu button is activated (mouse click, Enter, gamepad A,
--              and Esc / B for "back")
--     loading  played when the loading screen starts; the loading screen is held for
--              exactly as long as the sound (see sounds.loadingDuration)
--
-- WHERE THE FILES LIVE   <this folder>/sounds/
--
-- TO USE YOUR OWN: drop a file named  ui.ogg,  loading.ogg  and/or  intro.ogg  (or .mp3 / .wav)
-- into that folder. No code, no config. Yours wins over the bundled  example_ui.ogg  /
-- example_loading.ogg / example_intro.ogg ; delete the examples whenever you like (before shipping, say).
--
--     ui.ogg       -> example_ui.ogg        (first one found wins)
--     loading.ogg  -> example_loading.ogg
--     intro.ogg    -> example_intro.ogg
--
-- If several formats of the same name exist, the order is .ogg, then .mp3, then .wav.
-- File names are matched case-insensitively (Loading.MP3 works). Nothing found for a
-- slot = silence (and a loading screen that falls back to a default length): the
-- template still runs with no sounds at all.
--
-- Both play through audio.playSFX, so Settings -> Other -> SFX volume controls them.
-- The loading sound is not looped; it is exactly as long as the loading screen.
--
-- USAGE (main.lua shows the wiring; menu_input.lua already plays the click sound itself)
--   local sounds = require("ultimate_ui.ui_sounds")   -- or UI.sounds
--   sounds.playUI()                       -- the click sound, e.g. for your own buttons
--   sounds.playLoading()                  -- start the loading sound (returns the Source)
--   sounds.stopLoading()                  -- cut it off (the loading screen does this on finish)
--   sounds.playIntro() / sounds.stopIntro()  -- the intro sound (main.lua starts / stops it with the intro video)
--   sounds.loadingDuration(fallback)      -- length of the loading sound in seconds,
--                                         -- or `fallback` (default 2.0) if there is none
--   sounds.path("ui" | "loading")         -- the file in use, or nil
--   sounds.refresh()                      -- rescan the folder (UI.init() already did)

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")   -- the library folder (this file lives in src/)
local debuglog = require(ROOT .. ".src.debuglog")
local audio = require(ROOT .. ".src.audio")

local DIR = (ROOT:gsub("%.", "/")) .. "/sounds"   -- from the game root, e.g. "ultimate_ui/sounds"

-- Extensions LOVE can play, best first.
local EXTENSIONS = { "ogg", "mp3", "wav" }

-- slot -> base names to look for, best first (yours, then the bundled example).
local SLOTS = {
    ui      = { "ui",      "example_ui" },
    loading = { "loading", "example_loading" },
    intro   = { "intro",   "example_intro" },
}

local sounds = { dir = DIR }

local SLOT_ORDER = { "ui", "loading", "intro" }

local found = {}            -- slot -> path, or nil when nothing was found
local scanned = false       -- the folder is scanned on first use (or by refresh())
local loadingInstance = nil -- the playing loading Source, so it can be stopped
local introInstance = nil   -- the playing intro Source, so it can be stopped

-- Real file name in the folder for a lowercase name, so "Loading.MP3" matches on any OS.
local function folderIndex()
    local index = {}
    if love.filesystem.getInfo(DIR, "directory") then
        for _, name in ipairs(love.filesystem.getDirectoryItems(DIR)) do
            index[name:lower()] = name
        end
    end
    return index
end

function sounds.refresh()
    audio.clearSFXCache()
    found = {}
    scanned = true
    local index = folderIndex()

    for _, slot in ipairs(SLOT_ORDER) do
        local names = SLOTS[slot]
        for _, base in ipairs(names) do
            for _, ext in ipairs(EXTENSIONS) do
                local real = index[base .. "." .. ext]
                if real and not found[slot] then
                    found[slot] = DIR .. "/" .. real
                end
            end
            if found[slot] then break end
        end

        if found[slot] then
            debuglog.log("sounds: %s sound = %s", slot, found[slot])
        else
            debuglog.log("sounds: no %s sound in %s/ (drop %s.ogg or %s.mp3 there) -- staying silent",
                slot, DIR, names[1], names[1])
        end
    end
    return sounds
end

local function ensureScanned()
    if not scanned then sounds.refresh() end
end

function sounds.path(slot)
    ensureScanned()
    return found[slot]
end

-- Click sound for a menu button. Safe to call from anywhere, any time.
function sounds.playUI()
    ensureScanned()
    if found.ui then audio.playSFX(found.ui) end
end

-- Starts the loading sound (restarting it if it is already playing).
function sounds.playLoading()
    ensureScanned()
    sounds.stopLoading()
    if found.loading then
        loadingInstance = audio.playSFX(found.loading)
    end
    return loadingInstance
end

function sounds.stopLoading()
    if loadingInstance then
        loadingInstance:stop()
        loadingInstance = nil
    end
end

-- Starts the intro sound (restarting it if it is already playing). Silent if there is none.
function sounds.playIntro()
    ensureScanned()
    sounds.stopIntro()
    if found.intro then
        introInstance = audio.playSFX(found.intro)
    end
    return introInstance
end

function sounds.stopIntro()
    if introInstance then
        introInstance:stop()
        introInstance = nil
    end
end

-- Length of the loading sound in seconds -- pass this to loading_screen.start() so the
-- screen lasts exactly as long as the sound. `fallback` is used when there is no
-- (readable) loading sound.
function sounds.loadingDuration(fallback)
    ensureScanned()
    local duration = found.loading and audio.getSFXDuration(found.loading)
    if duration and duration > 0 then return duration end
    return fallback or 2.0
end

return sounds
