-- fonts.lua
-- Font registry + size cache.
--
-- Fonts live in fonts/ and may be NESTED: fonts/font_boldpixels/boldpixels.ttf,
-- fonts/my_pack/sub/thing.otf, ... Every .ttf / .otf found anywhere under fonts/ is registered.
-- Nothing is rasterized until it is asked for, so dropping in 20 families costs nothing.
--
-- NAMING A FONT -- any of these work (case-insensitive) wherever a font name is accepted:
--     "boldpixels"                         the family (folder name, "font_" prefix optional)
--     "pixeloid_sans"                      -> its main file (PixeloidSans.ttf)
--     "PixeloidSans-Bold"                  a file name without extension
--     "PixeloidSans-Bold.ttf"              a file name
--     "font_pixeloid_sans/PixeloidSans-Bold.ttf"   a path inside fonts/
--   fonts.list() prints every name that is available.
--
-- WHERE A FONT IS CHOSEN (most specific wins):
--     1. the element itself      { type = "label", font = "fibberish", ... }   (widget or stack item)
--     2. the element's ROLE      config.fontRoles = { button = "pixeloid_sans", title = "boldpixels" }
--     3. the project font        config.font = "boldpixels"      (everything that has no 1 or 2)
--     4. the first font found    (alphabetical)  /  LOVE's built-in font if fonts/ is empty
--   Roles used by the template: "title", "subtitle" (-> title), "button", "row" (-> button), "hint",
--   "stat", "hud" (-> stat), "body". A role with no font of its own uses the project font.
--   `fonts.setRole("button", "name")` / `fonts.setDefault("name")` change them live from code.
--
-- Fonts keep their own filter; they are not tied to texture_filter_manager.

local ROOT = (...):match("^(.*)%.[^.]+$")
local fonts = {}

-- love.filesystem paths start at the game root, so locate fonts/ from wherever this
-- library folder lives ("ultimate_ui/fonts", "libs/ultimate_ui/fonts", ...).
local FONT_DIR = (ROOT:gsub("%.", "/")) .. "/fonts"
local MAX_DEPTH = 6
local availableFontSizes = {12, 14, 16, 18, 20, 24, 30, 36, 42, 48, 52, 60, 72, 96}

local registry                 -- list of { path, rel, stem, family, keys = {...} }, built lazily
local lookupTable              -- lower-case name -> entry
local sizeCache = {}           -- [path][size] = Font
local runtimeDefault           -- set by fonts.setDefault
local runtimeRoles = {}        -- set by fonts.setRole  (role -> name)
local warned = {}

local function isFontFile(name)
    local n = name:lower()
    return n:match("%.ttf$") or n:match("%.otf$")
end

local function norm(s) return (s:lower():gsub("[^%w]", "")) end

local function warnOnce(fmt, ...)
    local msg = string.format(fmt, ...)
    if warned[msg] then return end
    warned[msg] = true
    local ok, debuglog = pcall(require, ROOT .. ".debuglog")
    if ok and debuglog.warn then debuglog.warn("%s", msg) else print("[ultimate_ui] " .. msg) end
end

local configTable
local function config()
    if not configTable then
        local ok, c = pcall(require, ROOT .. ".config")
        configTable = ok and type(c) == "table" and c or {}
    end
    return configTable
end

-- ---------------------------------------------------------------------------
-- scanning
-- ---------------------------------------------------------------------------
local function scan(dir, rel, depth, out)
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    for _, name in ipairs(items) do
        local full = dir .. "/" .. name
        local info = love.filesystem.getInfo(full)
        if info and info.type == "directory" and depth < MAX_DEPTH then
            scan(full, rel .. name .. "/", depth + 1, out)
        elseif info and info.type == "file" and isFontFile(name) then
            local stem = name:gsub("%.[^.]+$", "")
            local folder = rel:match("([^/]+)/$")                -- nearest folder, nil at the top
            out[#out + 1] = {
                path = full, rel = rel .. name, file = name, stem = stem,
                folder = folder, family = folder and folder:gsub("^[Ff][Oo][Nn][Tt][_%-%s]+", "") or stem,
            }
        end
    end
end

-- Picks the "main" file of a family: the one named like the folder, then a Regular/Classic/...
-- file, then the shortest name, then alphabetical.
local PLAIN = { "regular", "classic", "normal", "book", "medium", "roman" }
local function mainOf(list, familyKey)
    local best, bestScore
    for _, e in ipairs(list) do
        local s = norm(e.stem)
        local score = 1000 + #s
        if s == familyKey then score = 0
        else
            for _, p in ipairs(PLAIN) do
                if s:find(p, 1, true) then score = math.min(score, 100 + #s) end
            end
        end
        if not best or score < bestScore then best, bestScore = e, score end
    end
    return best
end

local function build()
    registry, lookupTable = {}, {}
    if not love.filesystem.getInfo(FONT_DIR) then return end
    scan(FONT_DIR, "", 0, registry)

    local families, order = {}, {}
    for _, e in ipairs(registry) do
        local fk = norm(e.family)
        if not families[fk] then families[fk] = {} order[#order + 1] = fk end
        table.insert(families[fk], e)

        local function add(key, force)
            key = key:lower()
            if force or lookupTable[key] == nil then lookupTable[key] = e end
        end
        add(e.rel, true)                       -- "font_x/File.ttf"
        add(e.file, false)                     -- "File.ttf"   (first wins if two folders share a name)
        add(e.stem, false)                     -- "File"
        if e.folder then add(e.folder .. "/" .. e.stem, false) end
    end
    for _, fk in ipairs(order) do
        local list = families[fk]
        local main = mainOf(list, fk)
        local e0 = list[1]
        -- family names: "pixeloid_sans", "font_pixeloid_sans", "pixeloidsans"
        for _, k in ipairs({ e0.family, e0.folder or e0.family, fk }) do
            local key = k:lower()
            if lookupTable[key] == nil then lookupTable[key] = main end
        end
        main.isMain = true
    end
end

local function ensure() if not registry then build() end end

-- Everything under fonts/, in a stable order: { { name =, path =, family =, main = bool }, ... }
-- `name` is the shortest unambiguous way to refer to the font (use it in config / widgets).
function fonts.list()
    ensure()
    local out = {}
    for _, e in ipairs(registry) do
        local name = (e.isMain and e.family or e.stem):lower()
        out[#out + 1] = { name = name, path = e.path, family = e.family, file = e.file, main = e.isMain or false }
    end
    return out
end

-- name -> path (or nil). Accepts every spelling listed at the top of this file.
function fonts.resolve(name)
    if name == nil or name == "" then return nil end
    ensure()
    local e = lookupTable[tostring(name):lower()] or lookupTable[tostring(name):lower():gsub("%.[^./]+$", "")]
    return e and e.path or nil
end

-- ---------------------------------------------------------------------------
-- the project font / roles
-- ---------------------------------------------------------------------------
-- Path of the project-wide font, or nil when fonts/ has none. Order: fonts.setDefault(), then
-- config.font, then the first font file found. An unknown name warns once and falls through.
function fonts.path()
    ensure()
    local wanted = runtimeDefault or config().font
    if wanted then
        local p = fonts.resolve(wanted)
        if p then return p end
        warnOnce("font \"%s\" was not found under %s/ (see UI.fonts.list()) -- using the first font found instead", tostring(wanted), FONT_DIR)
    end
    return registry[1] and registry[1].path or nil
end

-- A role with no font of its own borrows its sibling's before falling back to the project font.
local FALLBACK = { row = "button", subtitle = "title", hud = "stat" }
local ROLES = { "title", "subtitle", "button", "row", "hint", "stat", "hud", "body" }
local isRole = {}
for _, r in ipairs(ROLES) do isRole[r] = true end

-- Path for a role ("button", "title", ...): fonts.setRole(), then config.fontRoles, then the
-- sibling role (row -> button, subtitle -> title, hud -> stat), else the project font.
function fonts.rolePath(role)
    local guard = 0
    while role and guard < 3 do
        guard = guard + 1
        local name = runtimeRoles[role]
        if name == nil then
            local roles = config().fontRoles
            name = type(roles) == "table" and roles[role] or nil
        end
        if name then
            local p = fonts.resolve(name)
            if p then return p end
            warnOnce("fontRoles.%s = \"%s\" was not found under %s/ -- using the project font", role, tostring(name), FONT_DIR)
            break
        end
        role = FALLBACK[role]
    end
    return fonts.path()
end

-- Project-wide font from code:  fonts.setDefault("pixeloid_sans")   (nil = back to config.font)
function fonts.setDefault(name) runtimeDefault = name end
-- One element type:             fonts.setRole("button", "fibberish") (nil = back to config.fontRoles)
function fonts.setRole(role, name) runtimeRoles[role] = name end

-- ---------------------------------------------------------------------------
-- Font objects
-- ---------------------------------------------------------------------------
local meta = setmetatable({}, { __mode = "k" })   -- Font -> { path =, size = }  (for centering, below)

local function make(path, size)
    if path then
        local ok, font = pcall(love.graphics.newFont, path, size)
        if ok then meta[font] = { path = path, size = size } return font end
    end
    local font = love.graphics.newFont(size)
    meta[font] = { size = size }
    return font
end

-- Fresh (uncached) Font from the project font. Used by dev tooling.
function fonts.new(size) return make(fonts.path(), size) end

local function cached(path, size)
    local key = path or "<builtin>"
    local bySize = sizeCache[key]
    if not bySize then bySize = {} sizeCache[key] = bySize end
    local f = bySize[size]
    if not f then f = make(path, size) bySize[size] = f end
    return f
end

-- Call once from love.load(). Safe to call again (e.g. after a font swap): re-scans fonts/ and
-- pre-loads every size of the project font and of each role font.
function fonts.load()
    registry, lookupTable, sizeCache, warned = nil, nil, {}, {}
    local paths, seen = { fonts.path() or false }, {}
    for _, role in ipairs(ROLES) do
        paths[#paths + 1] = fonts.rolePath(role) or false
    end
    for _, p in ipairs(paths) do
        if not seen[p] then
            seen[p] = true
            for _, size in ipairs(availableFontSizes) do cached(p or nil, size) end
        end
    end
end

local function snap(requestedSize)
    requestedSize = math.floor(requestedSize)
    local best = availableFontSizes[1]
    for _, size in ipairs(availableFontSizes) do
        if size <= requestedSize then best = size else break end
    end
    return best
end

-- Font closest to (at or below) the requested size. `face` is optional and picks the font:
--   fonts.get(24)                    project font
--   fonts.get(24, "button")          the "button" role's font        (config.fontRoles)
--   fonts.get(24, nil, "fibberish")  a specific font name            (wins over the role)
-- A name given as `face` that is not a known role is tried as a font name, so
-- fonts.get(24, "fibberish") also works.
function fonts.get(requestedSize, face, explicit)
    if not registry then build() end
    local path
    if explicit then
        path = fonts.resolve(explicit)
        if not path then
            warnOnce("font \"%s\" was not found under %s/ -- using the role / project font", tostring(explicit), FONT_DIR)
        end
    end
    if not path and face then
        local roles = config().fontRoles
        if isRole[face] or runtimeRoles[face] ~= nil or (type(roles) == "table" and roles[face] ~= nil) then
            path = fonts.rolePath(face)
        else
            path = fonts.resolve(face)
        end
    end
    path = path or fonts.path()
    return cached(path, snap(requestedSize))
end

function fonts.sizes() return availableFontSizes end

-- ---------------------------------------------------------------------------
-- Vertical centering
-- ---------------------------------------------------------------------------
-- Fonts do not agree on where their capital letters sit inside the line box (ascent / descent
-- differ per family), so "y + (boxHeight - fontSize) / 2" lands high in one font and low in
-- another. fonts.capCenter() measures where the middle of the capitals really is, and
-- fonts.textY() uses it, so text is centered by what you SEE, in any font you drop in.
local capCache = setmetatable({}, { __mode = "k" })

-- Distance from the top of the font's line box to the middle of a capital "H", in pixels.
function fonts.capCenter(font)
    local c = capCache[font]
    if c then return c end
    c = font:getHeight() / 2                               -- fallback: middle of the line box
    local m = meta[font]
    if m then
        local ok, value = pcall(function()
            local r = m.path and love.font.newRasterizer(m.path, m.size) or love.font.newRasterizer(m.size)
            local g = r:getGlyphData("H")
            local _, bearingY = g:getBearing()
            local ascent, rAscent = font:getAscent(), r:getAscent()
            local scale = (rAscent and rAscent > 0) and (ascent / rAscent) or 1   -- high-DPI safe
            return ascent - (bearingY - g:getHeight() / 2) * scale
        end)
        if ok and type(value) == "number" and value > 0 and value < font:getHeight() * 1.5 then c = value end
    end
    capCache[font] = c
    return c
end

-- config.fontNudge = { fibberish = 0.05 }: extra shift in FRACTIONS OF THE FONT SIZE (+ = down) for
-- a font that still looks off after auto-centering. The key is any font name.
local function nudge(font)
    local m = meta[font]
    local t = config().fontNudge
    if not (m and m.path and type(t) == "table") then return 0 end
    for name, amount in pairs(t) do
        if fonts.resolve(name) == m.path and type(amount) == "number" then return amount * m.size end
    end
    return 0
end

-- The y to hand to love.graphics.print / printf so capital letters are centered in a box that
-- starts at boxY and is boxH tall. `font` defaults to the current font.
function fonts.textY(boxY, boxH, font)
    font = font or love.graphics.getFont()
    return math.floor(boxY + boxH / 2 - fonts.capCenter(font) + nudge(font) + 0.5)
end

-- Back-compat: the project font's pre-loaded sizes, { [size] = Font }.
function fonts.getAll()
    local out, path = {}, fonts.path()
    for _, size in ipairs(availableFontSizes) do out[size] = cached(path, size) end
    return out
end

return fonts
