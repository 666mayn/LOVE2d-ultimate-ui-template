-- fonts.lua
-- Pre-loads a fixed set of font sizes and resolves an arbitrary
-- requested size down to the closest available one (avoids
-- re-rasterizing a new Font object every frame for scaled UI text).
--
-- Drop ANY .ttf / .otf into the fonts/ folder next to this file (any file name) and it is used: the first
-- font file found (alphabetical) wins. To pick one when several are there, set
-- `font = "myfont.ttf"` in config.lua. If there is no usable font, LOVE's
-- built-in font is used instead so the template still runs.

local ROOT = (...):match("^(.*)%.[^.]+$")
local fonts = {}

-- love.filesystem paths start at the game root, so locate fonts/ from wherever this
-- library folder lives ("ultimate_ui/fonts", "libs/ultimate_ui/fonts", ...).
local FONT_DIR = (ROOT:gsub("%.", "/")) .. "/fonts"
local fontPath            -- resolved lazily, see fonts.path()
local availableFontSizes = {12, 14, 16, 18, 20, 24, 30, 36, 42, 48, 52, 60, 72, 96}
local loadedFonts = {}

local function isFontFile(name)
    local n = name:lower()
    return n:match("%.ttf$") or n:match("%.otf$")
end

-- Path of the font in use (e.g. "ultimate_ui/fonts/whatever.ttf"), or nil if fonts/ has none.
-- config.font (a file name inside fonts/) wins; otherwise the first font file found.
function fonts.path()
    if fontPath ~= nil then return fontPath or nil end
    fontPath = false
    local okc, config = pcall(require, ROOT .. ".config")
    local wanted = okc and type(config) == "table" and config.font or nil
    if wanted and love.filesystem.getInfo(FONT_DIR .. "/" .. wanted) then
        fontPath = FONT_DIR .. "/" .. wanted
    elseif love.filesystem.getInfo(FONT_DIR) then
        local found = {}
        for _, name in ipairs(love.filesystem.getDirectoryItems(FONT_DIR)) do
            if isFontFile(name) then found[#found + 1] = name end
        end
        table.sort(found)
        if found[1] then fontPath = FONT_DIR .. "/" .. found[1] end
    end
    return fontPath or nil
end

-- Loads a Font object from the resolved font file (LOVE's default if none/failed).
function fonts.new(size)
    local path = fonts.path()
    if path then
        local ok, font = pcall(love.graphics.newFont, path, size)
        if ok then return font end
    end
    return love.graphics.newFont(size)
end

-- Call once from love.load(). Safe to call again (e.g. after a font swap).
-- Fonts keep their own filter; they are not tied to texture_filter_manager.
function fonts.load()
    loadedFonts = {}
    fontPath = nil        -- re-scan fonts/ (you may have dropped a new one in)
    for _, size in ipairs(availableFontSizes) do
        loadedFonts[size] = fonts.new(size)
    end
end

-- Returns the pre-loaded font whose size is the closest match at or
-- below the requested size (never rounds up).
function fonts.get(requestedSize)
    if not loadedFonts[availableFontSizes[1]] then fonts.load() end
    requestedSize = math.floor(requestedSize)
    local bestSize = availableFontSizes[1]
    for _, size in ipairs(availableFontSizes) do
        if size <= requestedSize then
            bestSize = size
        else
            break
        end
    end
    return loadedFonts[bestSize]
end

function fonts.getAll()
    return loadedFonts
end

return fonts
