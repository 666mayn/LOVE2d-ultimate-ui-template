-- texture_filter_manager.lua
-- Simple, dependency-free manager for how your textures are sampled.
-- Replaces the old shader-based "crt_manager": instead of swapping post-
-- processing modules it just switches LOVE's texture filter mode, live,
-- and remembers the choice between runs.
--
-- Modes (edit `defs` to add/remove; each is just a min/mag filter pair):
--   SHARP   nearest / nearest   crisp pixels, the classic pixel-art look
--   SMOOTH  linear  / linear    blurry-smooth, good for high-res art
--   HYBRID  linear  / nearest   smooth when shrunk, crisp when enlarged
--
-- USAGE
--   1. love.load():   texture_filter_manager.init()     -- loads saved choice
--   2. Make images through the manager so they follow the setting live:
--        local img = texture_filter_manager.newImage("assets/tree.png")
--      (or call texture_filter_manager.track(anyImageOrCanvas) on ones you
--      made yourself). Tracked objects are held weakly -- they still get
--      garbage-collected normally.
--   3. Anything created AFTER init() also picks up the mode through
--      love.graphics.setDefaultFilter, so untracked images are right at
--      creation time; tracking just makes them update when the player
--      changes the mode mid-session.

local M = {}

local SAVE_FILE = "texture_filter_choice.txt"

local defs = {
    { id = "sharp",  name = "Sharp (Nearest)", min = "nearest", mag = "nearest" },
    { id = "smooth", name = "Smooth (Linear)", min = "linear",  mag = "linear"  },
    { id = "hybrid", name = "Hybrid",          min = "linear",  mag = "nearest" },
}

local DEFAULT_INDEX = 1 -- SHARP

local activeIndex = DEFAULT_INDEX
local tracked = setmetatable({}, { __mode = "k" }) -- weak keys: [drawable] = true

local function applyToDrawable(obj)
    local def = defs[activeIndex]
    if obj and obj.setFilter then
        pcall(obj.setFilter, obj, def.min, def.mag)
    end
end

local function applyAll()
    local def = defs[activeIndex]
    love.graphics.setDefaultFilter(def.min, def.mag)
    for obj in pairs(tracked) do applyToDrawable(obj) end
end

local function save()
    pcall(love.filesystem.write, SAVE_FILE, defs[activeIndex].id)
end

-- Call once from love.load().
function M.init()
    local wanted = DEFAULT_INDEX
    if love.filesystem.getInfo(SAVE_FILE) then
        local ok, saved = pcall(love.filesystem.read, SAVE_FILE)
        if ok and saved then
            saved = saved:match("^%s*(.-)%s*$")
            for i, d in ipairs(defs) do
                if d.id == saved then wanted = i break end
            end
        end
    end
    activeIndex = wanted
    applyAll()
end

-- Register an existing Image/Canvas so mode changes update it live.
-- Returns the object for chaining.
function M.track(obj)
    if obj then
        tracked[obj] = true
        applyToDrawable(obj)
    end
    return obj
end

-- Drop-in for love.graphics.newImage that auto-tracks the result.
function M.newImage(...)
    return M.track(love.graphics.newImage(...))
end

-- Drop-in for love.graphics.newCanvas that auto-tracks the result.
function M.newCanvas(...)
    return M.track(love.graphics.newCanvas(...))
end

-- ---- Menu-facing API (used by ui/texture_filter_menu.lua) ----
function M.getOptions()     return defs end
function M.getActiveIndex() return activeIndex end
function M.getActive()      return defs[activeIndex] end

-- Switch mode, apply it everywhere, persist it. Returns true on success.
function M.select(i)
    if not defs[i] then return false end
    activeIndex = i
    applyAll()
    save()
    return true
end

-- Convenience for a "cycle filter" keybind or button.
function M.cycle()
    return M.select(activeIndex % #defs + 1)
end

return M
