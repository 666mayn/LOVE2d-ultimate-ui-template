-- other_settings.lua
-- Single source of truth for the misc config/sound toggles exposed under
-- Settings -> Other (see ui/other_settings_menu.lua). Same shape as
-- keybinds.lua/controller.lua: pure data + a generic click-to-cycle
-- mechanism, no drawing code.
--
-- Each row here drives one field on another module's config table
-- (config.lua's fields, audio.lua's volumes). Rows write directly via
-- configRef/configField unless a `setter` function is given, in which case
-- that's called instead (used when the target module needs to clamp the
-- value and/or push it somewhere live, e.g. audio.setMusicVolume() also
-- updates the currently-playing track).
--
-- ADDING A ROW is just one more entry in ROW_DEFS; the menu and persistence
-- code below don't need to change. Replace the examples with your own.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")   -- the library folder (this file lives in src/)
local debuglog = require(ROOT .. ".src.debuglog")
local config = require(ROOT .. ".config")
local audio = require(ROOT .. ".src.audio")

local other_settings = {}

local function setFullscreen(value)
    config.fullscreen = value
    love.window.setFullscreen(value, "desktop")
end

local ROW_DEFS = {
    {
        id = "sfx_volume",
        label = "SFX VOLUME",
        type = "cycle",
        configRef = audio,
        configField = "globalSFXVolume",
        setter = audio.setSFXVolume, -- clamps + applies
        options = {
            { label = "MUTED",   value = 0.00 },
            { label = "QUIET",   value = 0.15 },
            { label = "NORMAL",  value = 0.3 },  -- matches audio.lua default
            { label = "LOUD",    value = 0.6 },
            { label = "LOUDEST", value = 0.98 },
        },
        defaultIndex = 3, -- "NORMAL"
    },
    {
        id = "music_volume",
        label = "MUSIC VOLUME",
        type = "cycle",
        configRef = audio,
        configField = "globalMusicVolume",
        setter = audio.setMusicVolume, -- clamps + updates live source volume
        options = {
            { label = "MUTED",   value = 0.00 },
            { label = "QUIET",   value = 0.2 },
            { label = "NORMAL",  value = 0.4 },  -- matches audio.lua default
            { label = "LOUD",    value = 0.7 },
            { label = "LOUDEST", value = 0.98 },
        },
        defaultIndex = 3, -- "NORMAL"
    },
    {
        -- Example of a plain config field. Multiply your shake magnitude by
        -- config.screenShakeIntensity (0 disables it).
        id = "screen_shake",
        label = "SCREEN SHAKE",
        type = "cycle",
        configRef = config,
        configField = "screenShakeIntensity",
        options = {
            { label = "OFF",    value = 0.0 },
            { label = "LOW",    value = 0.6 },
            { label = "NORMAL", value = 1.0 },
            { label = "HIGH",   value = 1.6 },
        },
        defaultIndex = 3, -- "NORMAL"
    },
    {
        -- Example of a boolean toggle read by ui/hud.lua's drawFPS().
        id = "show_fps",
        label = "SHOW FPS",
        type = "cycle",
        configRef = config,
        configField = "showFPS",
        options = {
            { label = "OFF", value = false },
            { label = "ON",  value = true },
        },
        defaultIndex = 1, -- "OFF"
    },
    {
        -- Example of a row driven by a setter that talks to LOVE directly.
        id = "fullscreen",
        label = "FULLSCREEN",
        type = "cycle",
        configRef = config,
        configField = "fullscreen",
        setter = setFullscreen,
        options = {
            { label = "OFF", value = false },
            { label = "ON",  value = true },
        },
        defaultIndex = 1, -- "OFF"
    },
}

other_settings.rowOrder = ROW_DEFS

local SAVE_PATH = "ultimate_ui_other_settings.txt"

-- id -> selected option index
local selections = {}

local function findDef(id)
    for _, def in ipairs(ROW_DEFS) do
        if def.id == id then return def end
    end
    return nil
end

local function applyRow(def)
    local option = def.options[selections[def.id]]
    if option then
        if def.setter then
            def.setter(option.value)
        else
            def.configRef[def.configField] = option.value
        end
    end
end

local function applyAll()
    for _, def in ipairs(ROW_DEFS) do
        applyRow(def)
    end
end

local function copyDefaults()
    selections = {}
    for _, def in ipairs(ROW_DEFS) do
        selections[def.id] = def.defaultIndex
    end
end

-- ==========================================
-- Getters used by ui/other_settings_menu.lua
-- ==========================================
function other_settings.getCurrentLabel(id)
    local def = findDef(id)
    if not def then return "?" end
    local option = def.options[selections[id]]
    return option and option.label or "?"
end

-- Advances the row's selection to the next option (wrapping), applies it
-- immediately, and persists it. Returns the new label for convenience.
function other_settings.cycle(id)
    local def = findDef(id)
    if not def then return nil end
    local count = #def.options
    selections[id] = (selections[id] % count) + 1
    applyRow(def)
    other_settings.save()
    return other_settings.getCurrentLabel(id)
end

function other_settings.resetToDefaults()
    copyDefaults()
    applyAll()
    other_settings.save()
end

-- ==========================================
-- Persistence
-- ==========================================
function other_settings.save()
    local lines = {}
    for id, index in pairs(selections) do
        table.insert(lines, id .. "=" .. tostring(index))
    end
    local ok, err = pcall(function()
        love.filesystem.write(SAVE_PATH, table.concat(lines, "\n"))
    end)
    if not ok then
        debuglog.log("other_settings.save() failed: %s", tostring(err))
    end
end

function other_settings.load()
    copyDefaults()
    if not love.filesystem.getInfo(SAVE_PATH) then
        applyAll()
        return
    end
    local ok, contents = pcall(love.filesystem.read, SAVE_PATH)
    if ok and contents then
        for line in contents:gmatch("[^\r\n]+") do
            local id, indexStr = line:match("^([%w_]+)=(%d+)$")
            local index = indexStr and tonumber(indexStr)
            local def = id and findDef(id)
            if def and index and def.options[index] then
                selections[id] = index
            end
        end
    end
    applyAll()
end

function other_settings.init()
    other_settings.load()
end

return other_settings
