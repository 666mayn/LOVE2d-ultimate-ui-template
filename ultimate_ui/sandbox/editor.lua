-- sandbox/editor.lua
-- Widget editor: click any title / button / label drawn by ui/widgets.lua,
-- change what it says and what color it is, then export the page as a
-- DROP-IN REPLACEMENT for its template file.
--
--   F11            edit mode on/off
--   click          select a widget            Esc   deselect (nothing selected: Esc/arrows/Enter go to the game)
--   Ctrl+click     press the button (uses the game, no editing)
--   type           change the text            Tab   switch TEXT <-> COLOR
--   COLOR field    #RRGGBB, or "rainbow"      Del   reset widget to original
--   Ctrl+V         paste (text field)
--   Ctrl+E         export this page -> exports/<its file>      (e.g. exports/ui/main_menu.lua)
--   Ctrl+Shift+E   export ALL pages -> exports/ (a complete set, edits included)
--   B (nothing selected)  cycle the test background (images in background/)   [ ]  blur less / more
--   - =  (nothing selected)  less / more dark dim over the background (the menu's own black overlay)
--
-- An export is the whole screen file, not a fragment: copy it over the file it
-- names (ui/main_menu.lua ...) and the template keeps working. It is written to
-- exports/ in the same folder layout as the project, so "drag exports/ui onto
-- the project root" installs every exported page at once.
--
-- The sandbox's own test background / dim are NOT written into an export unless you
-- picked them yourself (B, [ ], - =); otherwise the page keeps what its file says.
--
-- Edits are remembered in the save folder (ultimate_ui_sandbox_edits.txt), so they survive
-- the sandbox's auto-reload and restarts. Each saved edit also remembers what the
-- file said when you made it; if the file changes underneath (you dropped an
-- export in, or edited it by hand), that edit is dropped and the file wins.
-- Only screens built from ui/widgets.lua are editable (see widgets.screens).

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local serialize = require(ROOT .. ".sandbox.serialize")
local widgets = require(ROOT .. ".ui.widgets")
local menu_input = require(ROOT .. ".menu_input")
local fonts = require(ROOT .. ".fonts")
local bgui = require(ROOT .. ".ui.background")
local config = require(ROOT .. ".sandbox.config")
local theme = require(ROOT .. ".sandbox.theme")

local editor = {}

local EDITS_FILE = "ultimate_ui_sandbox_edits.txt"
local EXPORT_DIR = "exports"

-- Where this library lives in the project ("ultimate_ui", "libs/ultimate_ui", ...).
-- A screen's `file` is relative to it; exports mirror the PROJECT layout, so the
-- exports/ folder can be dragged straight onto the project root.
local LIB_DIR = (ROOT:gsub("%.", "/"))
local STALE_AFTER = 0.3          -- seconds without a widgets.draw => screen isn't data-driven

local SWATCHES = {
    "rainbow", "#FFFFFF", "#B0B0B0", "#FF4D4D", "#FF9F1C", "#FFC21F",
    "#6BFF7B", "#2EC4FF", "#4D6BFF", "#B04DFF", "#FF5FB4",
}

local active = false
local logger = function() end
local sel = nil                  -- { def, key, target, label, item }
local field = "text"             -- "text" | "color"
local buf = { text = "", color = "" }
local edits = nil                -- edits[screenId][key] = { text =, color =, from = {...} }
local originals = setmetatable({}, { __mode = "k" })   -- target -> { text =, color =  } as the FILE has them
local pristine = setmetatable({}, { __mode = "k" })    -- def -> { dim =, bg =, bgSpec = } as the FILE has them
local applied = setmetatable({}, { __mode = "k" })     -- defs already given their saved edits
local bgBlur = 8                 -- blur level used when a background is switched on

function editor.setLogger(fn) logger = fn or function() end end
function editor.active() return active end

-- ---------------------------------------------------------------------------
-- Colors
-- ---------------------------------------------------------------------------
local function toHex(c)
    if type(c) ~= "table" then return "rainbow" end
    local function b(v) return math.max(0, math.min(255, math.floor(v * 255 + 0.5))) end
    return string.format("#%02X%02X%02X", b(c[1]), b(c[2]), b(c[3]))
end

-- "rainbow" | "#RRGGBB" | "RRGGBB"  ->  "rainbow" | { r, g, b } (0..1) | nil
local function parseColor(str)
    str = (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if str:lower() == "rainbow" then return "rainbow" end
    local hex = str:match("^#?(%x%x%x%x%x%x)$")
    if not hex then return nil end
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
             tonumber(hex:sub(5, 6), 16) / 255 }
end

-- ---------------------------------------------------------------------------
-- Targets: every editable thing on a screen, by a stable key
--   label  -> "<widget id>"        stack item -> "<stack id>#<index>"
-- ---------------------------------------------------------------------------
local function targetsOf(def)
    local map = {}
    for _, w in ipairs(def.widgets) do
        if w.type == "label" then
            map[w.id] = w
        elseif w.type == "stack" or w.type == "stats" then
            for i, it in ipairs(w.items) do map[w.id .. "#" .. i] = it end
        end
    end
    return map
end

-- Remember what the FILE says for a target, before any edit touches it.
local function remember(target)
    if not originals[target] then
        originals[target] = { text = target.text, color = target.color }
    end
end

local function colorKey(c) return c ~= nil and toHex(c) or "none" end

-- ---------------------------------------------------------------------------
-- Persistence of edits (save folder)
-- ---------------------------------------------------------------------------
local function loadEdits()
    if edits then return end
    edits = {}
    if love.filesystem.getInfo(EDITS_FILE) then
        local chunk = love.filesystem.load(EDITS_FILE)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then edits = data end
        end
    end
end

local function saveEdits()
    local ok, err = pcall(function()
        love.filesystem.write(EDITS_FILE, "return " .. serialize.serialize(edits) .. "\n")
    end)
    if not ok then logger("could not save edits: %s", tostring(err)) end
end

local function bgSig(bg)
    return bg and ((bg.image or "") .. "|" .. tostring(bg.blur)) or "none"
end

-- numbers (or false/nil for "none") that differ by less than float noise are the same
local function sameNum(a, b)
    if not a or not b then return (not a) == (not b) end
    return math.abs(a - b) < 1e-5
end

-- Has the file changed since this edit was recorded? (`from` is what it said then.)
local function sourceChanged(target, from)
    if type(from) ~= "table" then return false end            -- older save: no record, trust it
    if from.text ~= nil and target.text ~= from.text then return true end
    if from.color ~= nil and colorKey(target.color) ~= from.color then return true end
    return false
end

-- The background picked for a widget screen (the main menu) is mirrored into the shared
-- menu background (config.menuBackground), so every other page -- pause, settings,
-- keyboard, ... -- shows the same picture, blur and dim. `cleared` = explicitly off.
local function mirrorShared(def, cleared)
    if def.background and def.background.image then
        bgui.setShared({ image = def.background.image, blur = def.background.blur, dim = def.dim })
    elseif cleared then
        bgui.setShared(nil)
    end
end

-- Does the sandbox's default test background belong on this screen?
local function wantsDefaultBackground(def)
    local only = config.defaultBackgroundScreens
    return only == nil or only[def.id] == true
end

-- Called by the sandbox every time a widget screen is drawn (and by export-all);
-- the first time a screen is seen, its saved edits are applied.
function editor.seen(def)
    if applied[def] then return end
    applied[def] = true
    loadEdits()
    local mine = edits[def.id] or {}
    local pr = { dim = def.dim, bg = bgSig(def.background),
                 bgSpec = def.background and { image = def.background.image, blur = def.background.blur } or nil }
    pristine[def] = pr
    local dropped = 0

    -- A static screen (the in-game HUD) draws over the game with no backdrop, so it
    -- has no dim / background to restore or mirror.
    if not def.static then
    -- dim (older saves stored a bare number)
    local d = mine.__dim
    if type(d) == "number" then d = { value = d } end
    if type(d) == "table" and d.from ~= nil and not sameNum(pr.dim, d.from) then
        mine.__dim, d, dropped = nil, nil, dropped + 1
    end
    if type(d) == "table" and type(d.value) == "number" then def.dim = d.value end

    -- background
    local bg = mine.__background
    if type(bg) == "table" and bg.from ~= nil and bg.from ~= pr.bg then
        mine.__background, bg, dropped = nil, nil, dropped + 1
    end
    if type(bg) == "table" then
        if bg.off then def.background = nil
        elseif bg.image then def.background = { image = bg.image, blur = bg.blur or bgBlur } end
        if bg.blur then bgBlur = bg.blur end
    elseif def.background == nil and wantsDefaultBackground(def) and not bgui.shared() then
        -- Nothing chosen yet: start with the sandbox's default test background.
        local dflt = config.defaultBackground
        local image = dflt and dflt.image
        if dflt and not (image and love.filesystem.getInfo(image)) then
            image = bgui.list()[1]               -- any image dropped in background/
        end
        if dflt and image then
            bgBlur = dflt.blur or bgBlur
            def.background = { image = image, blur = bgBlur }
            if d == nil and dflt.dim then def.dim = dflt.dim end
        end
    end

    mirrorShared(def, type(bg) == "table" and bg.off)
    end

    -- text / color of widgets
    local targets = targetsOf(def)
    for key, e in pairs(mine) do
        local t = targets[key]
        if t and key:sub(1, 2) ~= "__" then
            remember(t)
            if sourceChanged(t, e.from) then
                mine[key], dropped = nil, dropped + 1
            else
                if type(e.text) == "string" then t.text = e.text end
                if e.color ~= nil then t.color = e.color end
            end
        end
    end

    if dropped > 0 then
        saveEdits()
        logger("%s: file changed since your editor edits -- %d stale edit(s) dropped, the file wins",
            def.id, dropped)
    end
end

local function record(s)
    loadEdits()
    edits[s.def.id] = edits[s.def.id] or {}
    local o = originals[s.target] or {}
    local e = {}
    if type(s.target.text) == "string" then e.text = s.target.text end
    e.color = s.target.color

    local unchanged = (e.text == nil or e.text == o.text) and colorKey(e.color) == colorKey(o.color)
    if unchanged then
        edits[s.def.id][s.key] = nil
    else
        e.from = { text = type(o.text) == "string" and o.text or nil, color = colorKey(o.color) }
        edits[s.def.id][s.key] = e
    end
    saveEdits()
end

-- ---------------------------------------------------------------------------
-- Current screen + selection
-- ---------------------------------------------------------------------------
local function current()
    local last = widgets.last
    if last and (love.timer.getTime() - last.time) < STALE_AFTER then
        -- The HUD keeps drawing under a non-widget menu (Settings opened from Pause, ...):
        -- it is not editable while something covers it.
        if last.def.static and menu_input.getCurrentScreenName() then return nil end
        return last
    end
    return nil
end

local function itemKey(item)
    if item.kind == "label" then return item.id end
    return item.id .. "#" .. item.index
end

-- Screen-space box of an item (labels use the real text width, not the full row).
local function itemBox(item, last)
    if item.kind == "label" then
        local f = fonts.get(item.fontSize * last.uiScale)
        local tw = f:getWidth(item.text or "")
        return (last.width - tw) / 2, item.y, tw, item.h
    end
    return item.x, item.y, item.w, item.h
end

local function selectItem(item, last)
    local def = last.def
    local key = itemKey(item)
    local target = targetsOf(def)[key]
    if not target then return end
    remember(target)
    sel = { def = def, key = key, target = target, item = item,
            label = (item.kind == "label" and item.id or (item.text or key)) }
    -- Show the text as written in the file ("{config.title}"), not what it resolves to,
    -- so a binding survives until you deliberately type over it.
    buf.text = type(target.text) == "string" and target.text or (item.text or "")
    buf.color = toHex(item.color)
    field = "text"
end

-- Writes ONE field's buffer to the widget (so touching the text never pins its color).
local function applyBuffer(which)
    if not sel then return end
    if which == "text" then
        sel.target.text = buf.text
    else
        local c = parseColor(buf.color)
        if c then sel.target.color = c end
    end
    record(sel)
end

local function resetSelected()
    if not sel then return end
    local o = originals[sel.target]
    if o then
        sel.target.text, sel.target.color = o.text, o.color
    end
    loadEdits()
    if edits[sel.def.id] then edits[sel.def.id][sel.key] = nil end
    saveEdits()
    -- Refresh buffers from the restored values.
    local t = sel.target
    buf.text = type(t.text) == "function" and t.text() or (t.text or "")
    buf.color = toHex(t.color)
    logger("reset %s", sel.label)
end

-- ---------------------------------------------------------------------------
-- Background (B cycles images from background/, [ ] changes blur)
-- ---------------------------------------------------------------------------
local function recordBackground(def)
    loadEdits()
    edits[def.id] = edits[def.id] or {}
    local bg = def.background
    local from = pristine[def] and pristine[def].bg or nil
    edits[def.id].__background = bg and { image = bg.image, blur = bg.blur, from = from }
                                     or { off = true, blur = bgBlur, from = from }
    saveEdits()
end

local function cycleBackground()
    local last = current()
    if not last then return logger("no widget screen to put a background behind") end
    local def = last.def
    if def.static then return logger("the HUD draws over the game: it has no background") end
    local list = bgui.list()
    if #list == 0 then return logger("no images in %s/background/ (add a png or jpg)", LIB_DIR) end

    local idx = 0
    if def.background then
        for i, path in ipairs(list) do if path == def.background.image then idx = i end end
    end
    if idx < #list then
        def.background = { image = list[idx + 1], blur = (def.background and def.background.blur) or bgBlur }
        logger("background: %s  (blur %d)", list[idx + 1], def.background.blur)
    else
        def.background = nil
        logger("background off")
    end
    recordBackground(def)
    mirrorShared(def, true)
end

local function changeBlur(delta)
    local last = current()
    bgBlur = math.max(0, math.min(bgui.MAX_BLUR, bgBlur + delta))
    if last and last.def.background then
        last.def.background.blur = bgBlur
        recordBackground(last.def)
        mirrorShared(last.def)
    end
    logger("blur %d / %d", bgBlur, bgui.MAX_BLUR)
end

local function changeDim(delta)
    local last = current()
    if not last then return logger("no widget screen to dim") end
    local def = last.def
    if def.static then return logger("the HUD draws over the game: it has no dim") end
    def.dim = math.max(0, math.min(1, math.floor(((def.dim or 0) + delta) * 20 + 0.5) / 20))
    loadEdits()
    edits[def.id] = edits[def.id] or {}
    edits[def.id].__dim = { value = def.dim, from = (pristine[def] and pristine[def].dim) or false }
    saveEdits()
    mirrorShared(def)
    logger("dim %d%%", math.floor(def.dim * 100 + 0.5))
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------
-- Deep-copies a value as pure data. A function can't be written as data: a `text`
-- function is replaced by the text it shows right now, any other function is left
-- out, and each is reported in `warnings` (if given) so the file says so.
local function bake(v, warnings, where)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do
        if type(val) == "function" then
            if k == "text" then
                out[k] = val()
                if warnings then
                    warnings[#warnings + 1] = string.format(
                        '%s: text was a function, saved as what it shows now ("%s"). Use a {module.field} binding to keep it live.',
                        where, tostring(out[k]))
                end
            elseif warnings then
                warnings[#warnings + 1] = string.format(
                    '%s: %s() is a function and can\'t be exported, so it was left out. Use showIf = "module.field" instead of visible().',
                    where, tostring(k))
            end
        else
            out[k] = bake(val, warnings, where)
        end
    end
    return out
end
editor.bake = bake

local function safeRelPath(p)
    return type(p) == "string" and p:match("^[%w_%-%./]+%.lua$") ~= nil
        and not p:find("..", 1, true) and p:sub(1, 1) ~= "/"
end

local function fileOf(def) return def.file or ("ui/" .. def.id .. ".lua") end

local function projectFile(def) return LIB_DIR .. "/" .. fileOf(def) end

-- The `local ROOT = ...` line an exported screen starts with, so the file works
-- wherever the library folder is. Pattern depends on how deep the file sits.
local function rootLine(file)
    local n = 0
    for _ in file:gmatch("[^/]+") do n = n + 1 end
    if file:match("[^/]+$") == "init.lua" then n = n - 1 end
    return 'local ROOT = (...):match("^(.*)' .. ("%.[^.]+"):rep(n) .. '$")'
end

local function apiOf(def) return def.api or (def.id:sub(1, 1):upper() .. def.id:sub(2)) end

-- The complete replacement file for a screen. Returns source, warnings, file
-- (the project-relative path it replaces, e.g. "ultimate_ui/ui/main_menu.lua").
local function exportSource(def)
    local warnings = {}
    local data = {}
    for k, v in pairs(def) do
        if k == "widgets" then
            data.widgets = {}
            for _, w in ipairs(v) do
                data.widgets[#data.widgets + 1] = bake(w, warnings, 'widget "' .. tostring(w.id) .. '"')
            end
        elseif type(v) ~= "function" then
            data[k] = bake(v, warnings, "screen")
        end
    end
    data.file, data.api = fileOf(def), apiOf(def)
    local where = LIB_DIR .. "/" .. data.file          -- project-relative path of the file

    -- Dim / background: export what the FILE said unless you chose otherwise in the
    -- editor, so the sandbox's default test background never leaks into a drop-in.
    loadEdits()
    local mine, pr = edits[def.id] or {}, pristine[def]
    if pr then
        if not mine.__dim then data.dim = pr.dim end
        if not mine.__background then data.background = pr.bgSpec end
    end

    if not safeRelPath(data.file) then
        error("screen.file must be a plain relative .lua path (got " .. tostring(data.file) .. ")")
    end

    local api = data.api
    local L = {
        "-- " .. where .. "  (screen \"" .. def.id .. "\")",
        "-- Exported from the sandbox editor on " .. os.date("%Y-%m-%d %H:%M") .. ".",
        "--",
        "-- DROP-IN: copy this file over " .. where .. " in your project. Nothing else has to",
        "-- change -- it provides the functions ui/init.lua and menu_input.lua already call",
        "-- (draw" .. api .. ", handle" .. api .. "Click, getRowCount, getActionAt).",
        "--",
        "-- It is plain data: edit it by hand, or tweak it again in the editor (love . --sandbox,",
        "-- F11, Ctrl+E). To add a button, add { text = \"...\", action = \"...\" } to a stack and",
        "-- handle the action in menu_input.lua. In text, {config.title} pulls a live value;",
        "-- showIf = \"config.subtitle\" hides a widget while that value is empty. See ui/widgets.lua.",
    }
    if data.background and data.background.image then
        L[#L + 1] = "--"
        L[#L + 1] = "-- Background: " .. data.background.image .. " -- ship that file with your game."
    end
    for _, w in ipairs(warnings) do L[#L + 1] = "-- NOTE: " .. w end
    L[#L + 1] = ""
    L[#L + 1] = rootLine(data.file)
    L[#L + 1] = "local widgets = require(ROOT .. \".ui.widgets\")"
    L[#L + 1] = ""
    L[#L + 1] = "local screen = " .. serialize.serialize(data)
    L[#L + 1] = ""
    L[#L + 1] = "return widgets.screenModule(screen)"
    L[#L + 1] = ""
    return table.concat(L, "\n"), warnings, where
end
editor.exportSource = exportSource

local function isWindows() return package.config:sub(1, 1) == "\\" end
local function dirOf(p) return p:match("^(.*)/[^/]*$") or "" end

-- Writes outside the save folder when possible (so the file lands in the
-- project's exports/ folder); falls back to the save folder otherwise.
-- Returns the path to show (relative), the full path -- or nil, error.
local function writeExport(relFile, src)
    local rel = EXPORT_DIR .. "/" .. relFile
    local base = love.filesystem.getSource and love.filesystem.getSource() or nil
    if base and base ~= "" then
        local root = base:gsub("[/\\]+$", "")
        local path = root .. "/" .. rel
        local f = io.open(path, "wb")
        if not f then
            -- exports/<folder> may not exist yet: create it once, then retry.
            local dir = root .. "/" .. dirOf(rel)
            if not dir:find('["`$\n]') then
                if isWindows() then os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" >nul 2>nul')
                else os.execute('mkdir -p "' .. dir .. '" 2>/dev/null') end
                f = io.open(path, "wb")
            end
        end
        if f then
            f:write(src)
            f:close()
            return rel, path
        end
    end
    love.filesystem.createDirectory(dirOf(rel))
    local ok, err = love.filesystem.write(rel, src)
    if ok then
        local full = love.filesystem.getSaveDirectory() .. "/" .. rel
        return rel .. "  (save folder)", full
    end
    return nil, err
end

local function editableList()
    local ids = {}
    for _, d in ipairs(widgets.screens) do ids[#ids + 1] = d.id end
    return #ids > 0 and table.concat(ids, ", ") or "none"
end

local function exportDef(def, quiet)
    local ok, src, warnings, file = pcall(exportSource, def)
    if not ok then logger("export failed (%s): %s", tostring(def.id), tostring(src)) return false end
    local shown, full = writeExport(file, src)
    if not shown then logger("export failed (%s): %s", tostring(def.id), tostring(full)) return false end
    print("[sandbox] exported " .. tostring(full))
    for _, w in ipairs(warnings) do logger("note: %s", w) end
    if not quiet then logger("exported %s  -- drop it over %s", shown, file) end
    return true
end

-- Ctrl+E: the page you're looking at.
function editor.export()
    local last = current()
    if not last then
        return logger("nothing to export: this page isn't widget-based yet (editable: %s)", editableList())
    end
    exportDef(last.def)
end

-- Lets every widget page apply its saved edits / the default test background now, even
-- if it has not been drawn yet -- so the shared menu background is already in place
-- when you land straight on Settings, Pause, etc. Harmless to call every frame.
function editor.seenAll()
    for _, def in ipairs(widgets.screens) do editor.seen(def) end
end

-- Ctrl+Shift+E: every editable page, edits applied -- one complete set in exports/.
-- Pages you never touched come out exactly as their files describe them.
function editor.exportAll()
    loadEdits()
    local done, failed, edited = 0, 0, 0
    for _, def in ipairs(widgets.screens) do
        editor.seen(def)                       -- applies saved edits to pages not drawn yet
        local e = edits[def.id]
        if e and next(e) then edited = edited + 1 end
        if exportDef(def, true) then done = done + 1 else failed = failed + 1 end
    end
    if done == 0 and failed == 0 then return logger("nothing to export: no widget-based pages found") end
    logger("exported %d page(s) (%d edited) to %s/%s", done, edited, EXPORT_DIR,
        failed > 0 and ("  -- " .. failed .. " FAILED, see above") or "")
    if done > 0 then
        logger("install: drag %s/%s onto the project root, choose Replace, then restart",
            EXPORT_DIR, LIB_DIR:match("^[^/]+"))
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------
function editor.toggle()
    active = not active
    sel = nil
    logger("edit mode %s", active and "ON" or "off")
end

local function ctrl() return love.keyboard.isDown("lctrl", "rctrl") end
local function shift() return love.keyboard.isDown("lshift", "rshift") end

-- Returns true when the editor consumed the key.
function editor.keypressed(key)
    if not active then return false end
    if key:match("^f%d+$") then return false end      -- sandbox hotkeys keep working

    if key == "e" and ctrl() then
        if shift() then editor.exportAll() else editor.export() end
        return true
    end
    if key == "escape" then
        if sel then sel = nil return true end
        return false          -- nothing selected: Esc is the game's (pause / back)
    end
    if not sel then
        if key == "b" then cycleBackground() return true end
        if key == "[" then changeBlur(-1) return true end
        if key == "]" then changeBlur(1) return true end
        if key == "-" then changeDim(-0.05) return true end
        if key == "=" then changeDim(0.05) return true end
        return false
    end

    if key == "tab" then field = (field == "text") and "color" or "text"
    elseif key == "backspace" then
        local s = buf[field]
        local off = require("utf8").offset(s, -1)
        if off then buf[field] = s:sub(1, off - 1) end
        applyBuffer(field)
    elseif key == "delete" then resetSelected()
    elseif key == "v" and ctrl() and love.system and love.system.getClipboardText then
        local clip = (love.system.getClipboardText() or ""):gsub("[\r\n]+", " ")
        buf[field] = buf[field] .. clip
        applyBuffer(field)
    end
    return true                                       -- nothing leaks to the game
end

-- Keys the game still receives in edit mode while nothing is selected: Esc, arrows and
-- Enter. That lets you open the pause menu, walk its rows and go back without leaving
-- edit mode. (While a widget is selected every key belongs to the text field.)
local PASS = { escape = true, up = true, down = true, ["return"] = true, kpenter = true }
function editor.passesKey(key) return active and sel == nil and PASS[key] == true end

function editor.textinput(text)
    if not (active and sel) then return false end
    if field == "color" and #buf.color >= 9 then return true end
    buf[field] = buf[field] .. text
    applyBuffer(field)
    return true
end

-- Panel geometry (top-left, clear of the F1 panel on the right).
local function panel()
    local font = theme.font()
    local lh, pad = font:getHeight(), theme.PAD
    local fh = lh + 10                                   -- field height
    local labelW = font:getWidth("COLOR") + 12
    local x, y, w = 8, 8, 440
    local p = { x = x, y = y, w = w }
    local top = y + pad + lh + 10                        -- below the title row
    p.text  = { x = x + pad + labelW, y = top, w = w - pad * 2 - labelW, h = fh }
    p.color = { x = x + pad + labelW, y = top + fh + 8, w = 112, h = fh }
    p.sw = {}
    local sx = p.color.x + p.color.w + 12
    for i, c in ipairs(SWATCHES) do
        p.sw[i] = { x = sx + ((i - 1) % 6) * 30, y = p.color.y + math.floor((i - 1) / 6) * (fh / 2),
                    w = 26, h = math.floor(fh / 2) - 3, value = c }
    end
    p.h = (p.color.y + fh + 6 + lh + pad) - y
    p.errorY = p.color.y + fh + 6
    return p
end

local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function editor.mousepressed(x, y, button)
    if not active then return false end
    if button ~= 1 then return true end
    local last = current()
    local p = panel()

    if sel and inside(p, x, y) then
        if inside(p.text, x, y) then field = "text"
        elseif inside(p.color, x, y) then field = "color"
        else
            for _, s in ipairs(p.sw) do
                if inside(s, x, y) then buf.color = s.value field = "color" applyBuffer("color") break end
            end
        end
        return true
    end

    -- Ctrl+click uses the game: press RESUME / EXIT TO MENU / PLAY without leaving edit mode.
    if ctrl() then sel = nil return false end

    if last then
        for i = #last.items, 1, -1 do
            local item = last.items[i]
            local bx, by, bw, bh = itemBox(item, last)
            if x >= bx - 6 and x <= bx + bw + 6 and y >= by - 4 and y <= by + bh + 4 then
                selectItem(item, last)
                return true
            end
        end
    end
    sel = nil
    return true
end

-- Hint lines for the bottom-left hint area (see overlay.lua), or nil.
function editor.hints()
    if not active then return nil end
    local last = current()
    if not last then
        return { "EDIT MODE: this page isn't widget-based yet. Editable: " .. editableList()
                 .. "  |  F11 exit" }
    end
    local def = last.def
    local target = EXPORT_DIR .. "/" .. projectFile(def)
    if not sel and def.static then
        return { "EDIT MODE (HUD): click the title or a stat row to select it  |  Esc = pause",
                 "Ctrl+E export this page > " .. target .. "  |  Ctrl+Shift+E export all pages  |  F11 exit" }
    end
    if not sel then
        local bg = def.background
        return { "EDIT MODE: click a title or button to select it  |  Ctrl+click = press it  |  Esc = back",
                 "B = background (" .. (bg and bg.image:match("[^/]+$") or "off") .. ")  |  [ ] = blur " .. bgBlur
                     .. "/" .. bgui.MAX_BLUR
                     .. "  |  - = dim " .. math.floor((def.dim or 0) * 100 + 0.5) .. "%",
                 "Ctrl+E export this page > " .. target .. "  |  Ctrl+Shift+E export all pages  |  F11 exit" }
    end
    return { "EDITING \"" .. tostring(sel.label) .. "\":  type = change text  |  Tab = text/color field  |  Del = reset",
             "Ctrl+E export this page > " .. target .. "  |  Esc = deselect  |  F11 = exit edit mode" }
end

-- ---------------------------------------------------------------------------
-- Drawing (selection outlines + the small edit panel)
-- ---------------------------------------------------------------------------
function editor.draw()
    if not active then return end
    local last = current()
    local font = theme.font()
    local C = theme.color

    love.graphics.push("all")
    require(ROOT .. ".sandbox.overlay").cleanState()   -- ignore whatever the game left behind
    love.graphics.setFont(font)
    love.graphics.setLineWidth(2)

    if last then
        local mx, my = love.mouse.getPosition()
        for _, item in ipairs(last.items) do
            local bx, by, bw, bh = itemBox(item, last)
            local isSel = sel and sel.def == last.def and sel.key == itemKey(item)
            local hover = mx >= bx - 6 and mx <= bx + bw + 6 and my >= by - 4 and my <= by + bh + 4
            if isSel then love.graphics.setColor(C.select[1], C.select[2], C.select[3], 1)
            elseif hover then love.graphics.setColor(0.55, 0.9, 1, 0.9)
            else love.graphics.setColor(0.55, 0.9, 1, 0.3) end
            love.graphics.rectangle("line", math.floor(bx - 6), math.floor(by - 4),
                math.floor(bw + 12), math.floor(bh + 8))
        end
    end

    if sel and last then
        local p = panel()
        local lh = font:getHeight()
        theme.panel(p.x, p.y, p.w, p.h, 0.92)
        theme.print("EDITING  " .. tostring(sel.label), p.x + theme.PAD, p.y + theme.PAD, C.heading)

        local function fieldBox(r, label, value, focused)
            theme.print(label, p.x + theme.PAD, r.y + (r.h - lh) / 2, C.muted)
            love.graphics.setColor(focused and 0.16 or 0.09, focused and 0.16 or 0.09, focused and 0.24 or 0.11, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
            local ec = focused and C.select or { 0.4, 0.4, 0.45, 1 }
            love.graphics.setColor(ec[1], ec[2], ec[3], 1)
            love.graphics.setLineWidth(1)
            love.graphics.setLineStyle("rough")
            love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)

            local shown = value .. (focused and (math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or "") or "")
            local tw = font:getWidth(shown)
            local innerW = r.w - 12
            love.graphics.setScissor(r.x + 1, r.y + 1, r.w - 2, r.h - 2)
            theme.print(shown, r.x + 6 + math.min(0, innerW - tw), r.y + (r.h - lh) / 2, C.value)
            love.graphics.setScissor()
        end
        fieldBox(p.text, "TEXT", buf.text, field == "text")
        fieldBox(p.color, "COLOR", buf.color, field == "color")

        for _, s in ipairs(p.sw) do
            if s.value == "rainbow" then
                local cols = { { 1, .2, .2 }, { 1, .8, .2 }, { .3, 1, .4 }, { .2, .7, 1 }, { .7, .3, 1 } }
                local sw = s.w / #cols
                for i, c in ipairs(cols) do
                    love.graphics.setColor(c[1], c[2], c[3])
                    love.graphics.rectangle("fill", math.floor(s.x + (i - 1) * sw), s.y, math.ceil(sw), s.h)
                end
            else
                local c = parseColor(s.value)
                love.graphics.setColor(c[1], c[2], c[3])
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
            end
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", s.x + 0.5, s.y + 0.5, s.w - 1, s.h - 1)
        end
        if not parseColor(buf.color) then
            theme.print("use #RRGGBB or rainbow", p.x + theme.PAD, p.errorY, C.error)
        elseif buf.text:find("{", 1, true) and buf.text:find("}", 1, true) then
            theme.print("{module.field} stays live in the game", p.x + theme.PAD, p.errorY, C.muted)
        end
    end

    love.graphics.pop()
end

-- Exposed for tests.
editor._parseColor, editor._toHex, editor._targetsOf = parseColor, toHex, targetsOf
function editor._selection() return sel, field, buf end
function editor._reset() active, sel, edits = false, nil, nil end

return editor