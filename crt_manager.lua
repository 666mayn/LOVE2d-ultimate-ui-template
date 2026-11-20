-- crt_manager.lua
-- Optional full-screen post-processing ("CRT") filters, switchable at
-- runtime from Settings -> Textures. Sibling of texture_filter_manager.lua:
-- that one controls how textures are SAMPLED, this one controls a shader
-- applied to the finished frame. Pure Lua + LÖVE, no dependencies.
--
-- HOW IT WORKS
--   The whole frame is drawn into a canvas, then the canvas is drawn to the
--   screen through the selected filter's shader. With the filter set to OFF
--   the canvas is skipped entirely (zero cost).
--
-- USAGE (already wired up in main.lua)
--   love.load():    crt_manager.init()
--   love.update():  crt_manager.update(dt)
--   love.draw():    crt_manager.beginFrame()
--                   ...draw your game + UI...
--                   crt_manager.endFrame()
--   (resizes are handled automatically -- the canvas is rebuilt on demand)
--
-- ADDING A FILTER
--   1. Put a module in crt_filters/ that returns a table with:
--        init()                 -- build the shader, set default values
--        update(dt)             -- advance any animation clock (may be empty)
--        apply()                -- send uniforms + love.graphics.setShader(...)
--        endApply()             -- love.graphics.setShader()
--        settings = { ... }     -- optional, see below
--   2. Add one line to `defs` below.
--   That's it: the menu picks it up automatically.
--
-- FILTER SETTINGS (optional)
--   A filter's `settings` table becomes rows in the Textures menu:
--     { id = "glow", label = "GLOW", defaultIndex = 3,
--       apply = function(value) ... end,
--       options = { { label = "OFF", value = 0 }, { label = "ON", value = 1 }, ... } }
--   Choices are saved per filter, so each filter remembers its own.
--
-- NOTES
--   * A filter that fails to load or init (typo, shader error, missing file)
--     is shown as unavailable and skipped; it never crashes the game.
--   * Curved/pixelated filters change where things appear on screen, but
--     mouse hit-boxes stay on the unfiltered layout. Fine for most menus;
--     test it before shipping strong curvature on a mouse-driven UI.
--   * Saved to LÖVE's save folder as crt_filter_choice.txt.

local debuglog = require("debuglog")

local M = {}

local SAVE_FILE = "crt_filter_choice.txt"

-- The filter used on a fresh install (no save file). "off" ships the template
-- unfiltered; set to e.g. "classic" to default to a filter instead.
local DEFAULT_ID = "off"

-- One line per filter. `module = nil` means "no filter" (keep exactly one).
local defs = {
    { id = "classic", name = "Classic CRT",  module = "crt_filters.crt_filter"  },
    { id = "neon",    name = "Neon Arcade",  module = "crt_filters.crt_filter2" },
    { id = "lcd",     name = "Handheld LCD", module = "crt_filters.crt_filter3" },
    { id = "off",     name = "Off",          module = nil                       },
}

local loaded = {}       -- [i] = module table, or false if missing/broken
local initialized = {}  -- [i] = true once its init() has run
local selections = {}   -- selections[filterId][settingId] = chosen option index
local activeIndex = 1
local canvas = nil
local drawing = false   -- true between beginFrame() and endFrame()

-- ------------------------------------------------------------------
-- Internals
-- ------------------------------------------------------------------
local function indexOfId(id)
    for i, d in ipairs(defs) do
        if d.id == id then return i end
    end
    return nil
end

local function isOff(i)
    return defs[i] and defs[i].module == nil
end

local function loadModule(i)
    if loaded[i] ~= nil then return loaded[i] end
    local ok, mod = pcall(require, defs[i].module)
    if ok and type(mod) == "table" then
        loaded[i] = mod
    else
        debuglog.log("crt_manager: could not load %s: %s", defs[i].module, tostring(mod))
        loaded[i] = false
    end
    return loaded[i]
end

local function settingDefs(i)
    local mod = loaded[i]
    return (mod and mod.settings) or {}
end

local function chosenIndex(i, sdef)
    local byFilter = selections[defs[i].id]
    local idx = byFilter and byFilter[sdef.id]
    return (idx and sdef.options[idx]) and idx or sdef.defaultIndex
end

local function applySetting(i, sdef)
    local opt = sdef.options[chosenIndex(i, sdef)]
    if opt and sdef.apply then
        local ok, err = pcall(sdef.apply, opt.value)
        if not ok then
            debuglog.log("crt_manager: setting '%s' failed: %s", sdef.id, tostring(err))
        end
    end
end

local function applyAllSettings(i)
    for _, sdef in ipairs(settingDefs(i)) do applySetting(i, sdef) end
end

local function save()
    local lines = { "filter=" .. defs[activeIndex].id }
    for fid, byId in pairs(selections) do
        for sid, idx in pairs(byId) do
            lines[#lines + 1] = fid .. "." .. sid .. "=" .. tostring(idx)
        end
    end
    local ok, err = pcall(love.filesystem.write, SAVE_FILE, table.concat(lines, "\n"))
    if not ok then debuglog.log("crt_manager.save() failed: %s", tostring(err)) end
end

-- Loads + inits filter `i` (once) and pushes its saved settings into it.
-- Returns false if it can't be used.
local function activate(i)
    if isOff(i) then return true end
    local mod = loadModule(i)
    if not mod then return false end
    if not initialized[i] then
        if mod.init then
            local ok, err = pcall(mod.init)
            if not ok then
                debuglog.log("crt_manager: init failed for %s: %s", defs[i].module, tostring(err))
                loaded[i] = false
                return false
            end
        end
        initialized[i] = true
    end
    if mod.enabled ~= nil then mod.enabled = true end -- some filters have their own switch
    applyAllSettings(i)
    return true
end

local function activeModule()
    if isOff(activeIndex) then return nil end
    return loaded[activeIndex] or nil
end

local function ensureCanvas()
    local w, h = love.graphics.getDimensions()
    if canvas and canvas:getWidth() == w and canvas:getHeight() == h then return end
    canvas = love.graphics.newCanvas(w, h)
    -- Linear on purpose: curved filters resample this, and nearest looks
    -- jagged. Deliberately NOT tracked by texture_filter_manager.
    canvas:setFilter("linear", "linear")
end

-- ------------------------------------------------------------------
-- Lifecycle (called from main.lua)
-- ------------------------------------------------------------------
-- Safe to call again (e.g. after wiping saves): everything is re-read.
function M.init()
    loaded, initialized, selections, canvas, drawing = {}, {}, {}, nil, false

    local wanted = indexOfId(DEFAULT_ID) or #defs
    if love.filesystem.getInfo(SAVE_FILE) then
        local ok, contents = pcall(love.filesystem.read, SAVE_FILE)
        if ok and contents then
            for line in contents:gmatch("[^\r\n]+") do
                local fid, sid, idx = line:match("^([%w_]+)%.([%w_]+)=(%d+)$")
                if fid then
                    selections[fid] = selections[fid] or {}
                    selections[fid][sid] = tonumber(idx)
                else
                    local id = line:match("^filter=([%w_]+)$")
                    if id and indexOfId(id) then wanted = indexOfId(id) end
                end
            end
        end
    end

    if not activate(wanted) then
        wanted = indexOfId("off") or #defs -- saved filter is broken: fall back to Off
    end
    activeIndex = wanted
end

function M.update(dt)
    local mod = activeModule()
    if mod and mod.update then mod.update(dt) end
end

-- Start of the frame: redirect drawing into the canvas (no-op when Off).
function M.beginFrame()
    if not activeModule() then return end
    ensureCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(love.graphics.getBackgroundColor())
    drawing = true
end

-- End of the frame: draw the canvas to the screen through the filter.
function M.endFrame()
    if not drawing then return end
    drawing = false
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    local mod = activeModule()
    if mod then
        local ok, err = pcall(mod.apply)
        if not ok then debuglog.log("crt_manager: apply failed: %s", tostring(err)) end
    end
    love.graphics.draw(canvas, 0, 0)
    if mod and mod.endApply then pcall(mod.endApply) end
    love.graphics.setShader()
end

-- ------------------------------------------------------------------
-- Menu-facing API (used by ui/texture_filter_menu.lua)
-- ------------------------------------------------------------------
function M.getOptions()     return defs end
function M.getActiveIndex() return activeIndex end
function M.getActive()      return defs[activeIndex] end

-- False for a filter whose file is missing or failed to load.
function M.isAvailable(i)
    if not defs[i] then return false end
    if isOff(i) then return true end
    return loadModule(i) ~= false
end

-- Switch filter, persist it. Returns true on success.
function M.select(i)
    if not defs[i] or not activate(i) then return false end
    activeIndex = i
    save()
    return true
end

-- Next usable filter, wrapping around (handy for a hotkey too).
function M.cycle()
    for step = 1, #defs do
        if M.select((activeIndex - 1 + step) % #defs + 1) then return true end
    end
    return false
end

-- Rows for filter `i`'s settings: { { id =, label = }, ... }
function M.getSettingRows(i)
    local out = {}
    for _, sdef in ipairs(settingDefs(i)) do
        out[#out + 1] = { id = sdef.id, label = sdef.label }
    end
    return out
end

function M.getSettingLabel(i, settingId)
    for _, sdef in ipairs(settingDefs(i)) do
        if sdef.id == settingId then
            local opt = sdef.options[chosenIndex(i, sdef)]
            return opt and opt.label or "?"
        end
    end
    return "?"
end

-- Advance one setting of the ACTIVE filter to its next option.
function M.cycleSetting(settingId)
    for _, sdef in ipairs(settingDefs(activeIndex)) do
        if sdef.id == settingId then
            local fid = defs[activeIndex].id
            selections[fid] = selections[fid] or {}
            selections[fid][sdef.id] = (chosenIndex(activeIndex, sdef) % #sdef.options) + 1
            applySetting(activeIndex, sdef)
            save()
            return
        end
    end
end

-- Put the ACTIVE filter's settings back to their defaults.
function M.resetSettings()
    selections[defs[activeIndex].id] = nil
    applyAllSettings(activeIndex)
    save()
end

return M
