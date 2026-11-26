-- cursor.lua
-- Replaces the system mouse cursor with whatever image is in cursor/ (see cursor/README.md).
-- Drop a .png / .jpg / .bmp / .tga there (nested folders are fine; first one by path wins),
-- restart, done. No image = the normal system cursor.
--
--   UI.init() calls cursor.init() for you.
--   cursor.init()        (re)scan cursor/ and apply it
--   cursor.set(path)     use one specific image file (from the game root)
--   cursor.reset()       back to the system cursor
--   cursor.path()        the file in use, or nil
--
-- config.lua:  cursor = true|false,  cursorSize = 32 (longest side, px),
--              cursorHotspot = { 0.5, 0.5 } (the clicking pixel, as fractions of the image)

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")   -- the library folder (this file lives in src/)
local debuglog = require(ROOT .. ".src.debuglog")
local config = require(ROOT .. ".config")

local cursor = {}

local DIR = (ROOT:gsub("%.", "/")) .. "/cursor"
local MAX_DEPTH = 6
local EXT = { png = true, jpg = true, jpeg = true, bmp = true, tga = true }

local current = nil      -- the love Cursor (kept referenced: LOVE frees a Cursor that is garbage collected)
local usedPath = nil

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
            elseif info.type == "file" then
                local ext = name:lower():match("%.([^.]+)$")
                if ext and EXT[ext] then out[#out + 1] = path end
            end
        end
    end
end

-- Every usable image under cursor/, sorted by path.
function cursor.list()
    local out = {}
    if love.filesystem.getInfo(DIR, "directory") then scan(DIR, 1, out) end
    return out
end

-- Shrinks `src` so its longest side is `size` px. Averages up to 4x4 samples per pixel
-- (alpha-weighted, so edges don't get dark fringes). Images already that small are kept.
local function fit(src, size)
    local sw, sh = src:getDimensions()
    local longest = math.max(sw, sh)
    if longest <= size then return src end
    local f = size / longest
    local tw, th = math.max(1, math.floor(sw * f + 0.5)), math.max(1, math.floor(sh * f + 0.5))
    local out = love.image.newImageData(tw, th)
    local bx, by = sw / tw, sh / th
    local n = 4
    for y = 0, th - 1 do
        for x = 0, tw - 1 do
            local r, g, b, a = 0, 0, 0, 0
            for j = 0, n - 1 do
                local sy = math.min(sh - 1, math.floor((y + (j + 0.5) / n) * by))
                for i = 0, n - 1 do
                    local sx = math.min(sw - 1, math.floor((x + (i + 0.5) / n) * bx))
                    local pr, pg, pb, pa = src:getPixel(sx, sy)
                    r, g, b, a = r + pr * pa, g + pg * pa, b + pb * pa, a + pa
                end
            end
            if a > 0 then out:setPixel(x, y, r / a, g / a, b / a, a / (n * n)) end
        end
    end
    return out
end

function cursor.reset()
    current, usedPath = nil, nil
    if love.mouse and love.mouse.setCursor then pcall(love.mouse.setCursor) end   -- no argument = system default
end

-- Applies one image file as the cursor. Returns true on success.
function cursor.set(path)
    if not (love.mouse and love.mouse.newCursor and love.mouse.isCursorSupported()) then return false end
    local ok, result = pcall(function()
        local size = tonumber(config.cursorSize) or 32
        local data = fit(love.image.newImageData(path), math.max(8, math.min(128, size)))
        local hot = type(config.cursorHotspot) == "table" and config.cursorHotspot or { 0.5, 0.5 }
        local hx = math.max(0, math.min(data:getWidth() - 1, math.floor(data:getWidth() * (hot[1] or 0.5))))
        local hy = math.max(0, math.min(data:getHeight() - 1, math.floor(data:getHeight() * (hot[2] or 0.5))))
        return love.mouse.newCursor(data, hx, hy)
    end)
    if not ok then
        debuglog.warn("cursor: could not use \"%s\": %s", tostring(path), tostring(result))
        return false
    end
    current, usedPath = result, path
    love.mouse.setCursor(current)
    return true
end

function cursor.path() return usedPath end

function cursor.init()
    cursor.reset()
    if config.cursor == false then return end
    local files = cursor.list()
    if #files == 0 then
        debuglog.log("cursor: no image in %s/ -- using the system cursor", DIR)
        return
    end
    if cursor.set(files[1]) then
        debuglog.log("cursor: %s", files[1])
    end
end

return cursor
