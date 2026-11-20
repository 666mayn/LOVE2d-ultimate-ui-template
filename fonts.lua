-- fonts.lua
-- Pre-loads a fixed set of font sizes and resolves an arbitrary
-- requested size down to the closest available one (avoids
-- re-rasterizing a new Font object every frame for scaled UI text).
--
-- Drop your own .ttf in fonts/ and change `fontPath`. If the file is
-- missing or fails to load, LOVE's built-in font is used instead so the
-- template still runs.

local fonts = {}

local fontPath = "fonts/boldpixels.ttf"
local availableFontSizes = {12, 14, 16, 18, 20, 24, 30, 36, 42, 48, 52, 60, 72, 96}
local loadedFonts = {}

-- Call once from love.load(). Safe to call again (e.g. after a font swap).
-- Fonts keep their own filter; they are not tied to texture_filter_manager.
function fonts.load()
    loadedFonts = {}
    for _, size in ipairs(availableFontSizes) do
        local ok, font = pcall(love.graphics.newFont, fontPath, size)
        if not ok then font = love.graphics.newFont(size) end
        loadedFonts[size] = font
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
