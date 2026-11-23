-- ui/widgets.lua
-- Widget data model + renderer (prototype).
--
-- A screen is described as DATA (a plain Lua table). One layout pass turns it
-- into rectangles, and the same rectangles are used for drawing, hover and
-- click hit-testing, so the three can never drift apart. This is the format
-- the future drag-and-drop editor will read, edit, and export.
--
-- All sizes/offsets are in 1080p reference pixels and are multiplied by
-- uiScale (height / 1080) at layout time.
--
-- Screen definition:
--   {
--     id      = "mainMenu",        -- popup-animation key (see ui/helpers.lua)
--     file    = "ui/main_menu.lua",-- where this screen lives, relative to the ultimate_ui folder (the editor exports a replacement for it)
--     api     = "MainMenu",        -- names the functions the module provides: draw<Api>, handle<Api>Click
--     dim     = 180/255,           -- optional full-screen black overlay alpha (0..1)
--     background = { image = "ultimate_ui/background/your_image.png", blur = 8 },   -- path from the game root
--                                  -- optional picture behind everything (see ui/background.lua).
--                                  -- Leave it out to inherit the shared menu background
--                                  -- (config.menuBackground) that every menu page uses.
--     widgets = { <widget>, ... }  -- laid out IN ORDER; a widget may reference earlier ones
--   }
--
-- Widget types:
--   label  { id, type="label", text=<string|function>, fontSize=72, color=<"rainbow"|{r,g,b}>,
--            relativeTo=<widget id>, offset={dx,dy}, pop={delay,duration},
--            showIf="config.subtitle" | visible=<function> }
--          Centered across the full screen width. y = (top of relativeTo) + offset[2].
--   stack  { id, type="stack", size={w,h}, spacing=20, color=<...>,
--            pop={delay,stagger,duration}, items={ {text, action, color, gapBefore}, ... } }
--          A vertical column of buttons, centered on screen. Each item is one
--          keyboard/gamepad row, in order. `gapBefore` adds extra space above an item;
--          an item's own `color` overrides the stack's.
--
--   stats  { id, type="stats", x=40, y=140, lineHeight=40, fontSize=30, color=<...>, items={ {}, {}, ... } }
--          A left-aligned column of "LABEL:  value" lines for an in-game HUD. The game feeds the
--          rows each frame with widgets.setData(screenId, widgetId, { {"LABEL", value}, ... }).
--          items[i] is an optional override for row i: { text = "NEW LABEL", color = ... } (the value
--          always comes from the game). Keep a few empty {} entries so the editor can select rows.
--
-- Screen flag  static = true  marks an overlay that draws OVER the game (the HUD): no shared
-- background, no dim, no pop-in animation, never a menu.
--
-- Text may contain {module.field} (e.g. "{config.title}"): it is looked up live every
-- frame, so the screen follows your config. `showIf = "module.field"` hides a widget while
-- that value is nil / false / "". Both stay plain data, so the editor can export them.
-- (A text or visible FUNCTION still works in hand-written screens, but can't be exported.)
--
-- widgets.screenModule(screen) turns a screen table into the module a ui/ file returns
-- (draw<Api>, handle<Api>Click, getRowCount, getActionAt) and registers it in
-- widgets.screens, which is the list of pages the editor can edit and export.
--
-- widgets.textPage{...} is the lighter sibling of screenModule for the HAND-CODED pages
-- (Settings, Keyboard, Controller, Other, Textures, Loading): their layout and logic stay in
-- Lua, but every title / button / row label / hint line is described as data so the sandbox
-- editor (F11) can edit it too. See the "Text pages" section below.
--
-- FONTS: every widget (label, stack, stats) and every stack item / stats row may carry
--   font = "fibberish"      one font for just this element (any name fonts.lua knows; an item's
--                           font beats its stack's)
--   role = "title"          which ROLE the element belongs to (labels default to "title", the
--                           "subtitle" / "hint" ids to their own, stack buttons to "button",
--                           stats to "stat" / "hud"); config.fontRoles = { title = "boldpixels" }
--                           then sets the font of every element with that role at once.
-- With neither, the element uses its role's font, else the project font (config.font).
-- See ultimate_ui/fonts.lua.
--
-- Colors are "rainbow" (the animated default) or { r, g, b } with each 0..1.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local helpers = require(ROOT .. ".ui.helpers")
local background = require(ROOT .. ".ui.background")
local ui_state = require(ROOT .. ".ui_state")
local getFont = helpers.getFont

local widgets = {}

local function floor(n) return math.floor(n) end

-- Resolve a color spec to 0-255 r,g,b (the unit helpers.drawScaledButton takes).
local function resolveColor(spec)
    if spec == "rainbow" or spec == nil then
        return helpers.getRainbowColor(ui_state.getState().pulseTime)
    end
    return spec[1] * 255, spec[2] * 255, spec[3] * 255
end

-- module.field lookup for {bindings} and showIf (nil when the module/field is missing).
-- The module name is tried inside this library first ("config" -> <lib>.config),
-- then as a plain module of your own, so {game.score} still works for a game.lua
-- in your project. Results (including misses) are cached: this runs every frame.
local modCache = {}
local function lookup(mod, field)
    local m = modCache[mod]
    if m == nil then
        local ok, found = pcall(require, ROOT .. "." .. mod)
        if not ok then ok, found = pcall(require, mod) end
        m = (ok and type(found) == "table") and found or false
        modCache[mod] = m
    end
    if m then return m[field] end
    return nil
end

local function resolveText(t)
    if type(t) == "function" then return t() end
    if type(t) == "string" and t:find("{", 1, true) then
        -- unknown bindings are left as typed, so a typo is visible instead of blank
        return (t:gsub("{([%w_%.]+)%.([%w_]+)}", function(mod, field)
            local v = lookup(mod, field)
            if v ~= nil then return tostring(v) end
        end))
    end
    return t
end

widgets.resolveText = resolveText

local function shown(w)
    if w.visible and not w.visible() then return false end
    if w.showIf then
        local mod, field = w.showIf:match("^([%w_%.]+)%.([%w_]+)$")
        local v = mod and lookup(mod, field)
        if v == nil or v == false or v == "" then return false end
    end
    return true
end

-- Live data for "stats" widgets, kept OUTSIDE the screen table so exports never
-- contain it. Key: "<screen id>.<widget id>".
widgets.data = {}
function widgets.setData(screenId, widgetId, list)
    widgets.data[screenId .. "." .. widgetId] = list
end

-- Layout pass. Returns:
--   items  : flat draw-ordered list of { kind, x, y, w, h, ... } rects
--   rows   : the interactive items only, in keyboard/gamepad row order
-- Interactive item i has `index == i`, which equals the menu selection value.
function widgets.layout(def, screenWidth, screenHeight, uiScale)
    local items, rows, byId = {}, {}, {}
    local centerX = floor(screenWidth / 2)

    for _, w in ipairs(def.widgets) do
        if shown(w) then
            if w.type == "stack" then
                local bw = floor(w.size[1] * uiScale)
                local bh = floor(w.size[2] * uiScale)
                local spacing = floor((w.spacing or 0) * uiScale)
                local pop = w.pop or {}

                local n = #w.items
                local gaps = {}
                local totalGap = 0
                for i, it in ipairs(w.items) do
                    gaps[i] = it.gapBefore and floor(it.gapBefore * uiScale) or 0
                    totalGap = totalGap + gaps[i]
                end
                local totalHeight = n * bh + (n - 1) * spacing + totalGap
                local startY = floor(screenHeight / 2 - totalHeight / 2)

                local y = startY
                for i, it in ipairs(w.items) do
                    y = y + gaps[i]
                    local item = {
                        kind = "button", widget = w, id = w.id,
                        text = resolveText(it.text), action = it.action,
                        x = centerX - bw / 2, y = y, w = bw, h = bh, cx = centerX,
                        color = it.color or w.color, index = i,
                        font = it.font or w.font,
                        popDelay = (pop.delay or 0) + (i - 1) * (pop.stagger or 0),
                        popDuration = pop.duration or 0.4,
                    }
                    items[#items + 1] = item
                    rows[#rows + 1] = item
                    y = y + bh + spacing
                end
                -- Remember where the block starts so other widgets can hang off it.
                byId[w.id] = { x = centerX - bw / 2, y = startY, w = bw, h = totalHeight }

            elseif w.type == "label" then
                local ref = w.relativeTo and byId[w.relativeTo]
                local off = w.offset or { 0, 0 }
                local y = (ref and ref.y or 0) + off[2] * uiScale
                local h = w.fontSize * uiScale
                local pop = w.pop or {}
                local item = {
                    kind = "label", widget = w, id = w.id,
                    text = resolveText(w.text), fontSize = w.fontSize,
                    font = w.font, role = w.role or ((w.id == "subtitle" or w.id == "hint") and w.id or "title"),
                    x = 0, y = y, w = screenWidth, h = h,
                    color = w.color,
                    popDelay = pop.delay or 0, popDuration = pop.duration or 0.5,
                }
                items[#items + 1] = item
                byId[w.id] = item

            elseif w.type == "stats" then
                local list = widgets.data[def.id .. "." .. w.id] or {}
                local fs = w.fontSize or 30
                local lh = (w.lineHeight or 40) * uiScale
                local role = w.role or (def.static and "hud" or "stat")
                for i, stat in ipairs(list) do
                    local ov = w.items and w.items[i] or nil
                    local fontName = (ov and ov.font) or w.font
                    local font = getFont(fs * uiScale, role, fontName)
                    local label = (ov and ov.text ~= nil) and resolveText(ov.text) or tostring(stat[1])
                    local shownText = label .. ":  " .. tostring(stat[2])
                    items[#items + 1] = {
                        kind = "stat", widget = w, id = w.id, index = i,
                        text = label, shownText = shownText, fontSize = fs,
                        font = fontName, role = role,
                        x = (w.x or 0) * uiScale, y = (w.y or 0) * uiScale + (i - 1) * lh,
                        w = font:getWidth(shownText), h = fs * uiScale,
                        color = (ov and ov.color) or w.color,
                    }
                end
            end
        end
    end
    return items, rows
end

local function hit(item, mx, my)
    return mx >= item.x and mx <= item.x + item.w and my >= item.y and my <= item.y + item.h
end

-- Draws a screen. `selection` is the keyboard/gamepad row index; mouseX/mouseY
-- may be nil (no mouse). Hover wins over selection while the mouse is on a row.
function widgets.draw(def, screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local static = def.static               -- overlay on the game (HUD): no backdrop, no pop-in
    local t = static and 0 or helpers.getPopupTime(def.id)

    -- A screen's own `background` wins; otherwise it shows the shared menu
    -- background (config.menuBackground), with that background's dim.
    if not static then
        local dim = def.dim
        if def.background then
            background.draw(def.background, screenWidth, screenHeight)
        else
            local shared = background.shared()
            if shared then
                background.draw(shared, screenWidth, screenHeight)
                dim = shared.dim or dim
            end
        end

        if dim then
            love.graphics.setColor(0, 0, 0, dim)
            love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        end
    end

    local items, rows = widgets.layout(def, screenWidth, screenHeight, uiScale)

    local anyHovered = false
    for _, row in ipairs(rows) do
        row.hovered = (mouseX and mouseY and hit(row, mouseX, mouseY)) and true or false
        if row.hovered then anyHovered = true end
    end

    for _, item in ipairs(items) do
        local r, g, b = resolveColor(item.color)
        local scale, alpha = 1, 1
        if not static then scale, alpha = helpers.popIn(t, item.popDelay, item.popDuration) end
        if item.kind == "stat" then
            love.graphics.setColor(r / 255, g / 255, b / 255, alpha)
            love.graphics.setFont(getFont(item.fontSize * uiScale, item.role, item.font))
            love.graphics.print(item.shownText, item.x, item.y)
        elseif item.kind == "label" then
            helpers.withPop(screenWidth / 2, item.y + item.h / 2, scale, alpha, function()
                love.graphics.setColor(r / 255, g / 255, b / 255, alpha)
                love.graphics.setFont(getFont(item.fontSize * uiScale, item.role, item.font))
                love.graphics.printf(item.text, 0, item.y, screenWidth, "center")
            end)
        else
            helpers.withPop(item.cx, item.y + item.h / 2, scale, alpha, function()
                helpers.drawScaledButton(item.text, item.cx, item.y, item.w, item.h,
                    selection == item.index, item.hovered, anyHovered, uiScale, r, g, b, alpha, item.font)
            end)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- Remember what was just drawn so dev tools (the sandbox editor) can see it.
    widgets.last = { def = def, items = items, uiScale = uiScale,
                     width = screenWidth, height = screenHeight, time = love.timer.getTime() }
end

-- Returns the `action` of the interactive row under (x, y), or nil.
function widgets.click(def, x, y, screenWidth, screenHeight, uiScale)
    local _, rows = widgets.layout(def, screenWidth, screenHeight, uiScale)
    for _, row in ipairs(rows) do
        if hit(row, x, y) then return row.action end
    end
    return nil
end

function widgets.getRowCount(def)
    local n = 0
    for _, w in ipairs(def.widgets) do
        if w.type == "stack" then n = n + #w.items end
    end
    return n
end

function widgets.getActionAt(def, index)
    if not index or index < 1 then return nil end
    local n = 0
    for _, w in ipairs(def.widgets) do
        if w.type == "stack" then
            if index <= n + #w.items then return w.items[index - n].action end
            n = n + #w.items
        end
    end
    return nil
end

-- The list of screens the editor can edit, filled by screenModule().
widgets.screens = {}

-- Wraps a screen table into a ui/ module: the four functions ui/init.lua and
-- menu_input.lua call, named after screen.api ("MainMenu" -> drawMainMenu, ...).
-- Calls go through `widgets.draw` at call time so dev tools can hook it.
function widgets.screenModule(screen)
    local api = screen.api or (screen.id:sub(1, 1):upper() .. screen.id:sub(2))
    local replaced = false
    for i, s in ipairs(widgets.screens) do
        if s.id == screen.id then widgets.screens[i] = screen replaced = true end
    end
    if not replaced then widgets.screens[#widgets.screens + 1] = screen end

    local m = { screen = screen }
    m["draw" .. api] = function(w, h, selection, mx, my, uiScale)
        widgets.draw(screen, w, h, selection, mx, my, uiScale)
    end
    m["handle" .. api .. "Click"] = function(x, y, w, h, uiScale)
        return widgets.click(screen, x, y, w, h, uiScale)
    end
    m.getRowCount = function() return widgets.getRowCount(screen) end
    m.getActionAt = function(index) return widgets.getActionAt(screen, index) end
    return m
end

-- ---------------------------------------------------------------------------
-- Text pages
-- ---------------------------------------------------------------------------
-- A text page is a hand-coded screen (its own layout, its own clicks) whose STRINGS are
-- still data. The page keeps drawing itself, but reads every piece of text through the page
-- object, and reports the boxes it drew, so the sandbox editor (F11) can select and edit
-- them exactly like a widget screen:
--
--   local page = widgets.textPage{
--       id = "settingsMenu", file = "ui/settings_menu.lua",
--       labels = {                                   -- fixed texts, by id
--           { id = "title", text = "S E T T I N G S", fontSize = 60, color = "rainbow" },
--           { id = "hint",  text = "Esc to go back",  fontSize = 18, color = { 0.6, 0.6, 0.6 } },
--       },
--   }
--   local item = page.item("keyboard", "K E Y B O A R D")   -- a button / row label, by stable key
--   item.text                                               -- what to draw (edits already applied)
--   local r, g, b = page.rgb(item, r, g, b)                  -- 0-255; the item's own color if it has one
--   page.report(items, w, h, uiScale)                        -- call at the end of draw (see below)
--
-- Row keys must be stable (an action name, a row id, ...), not a position, so a saved edit
-- keeps following its row when rows are added or reordered.
--
-- Edits survive a restart in two layers: the sandbox remembers them in the save folder, and
-- Ctrl+E (or Ctrl+Shift+E) writes them ALL to exports/<lib>/ui/page_texts.lua. Drop that file
-- over ui/page_texts.lua and every text page picks the texts up at startup, with no editor.

-- ui/page_texts.lua, loaded once: { [screenId] = { [key] = { text =, color = } } }.
-- It is optional; a missing file (or one with an error, which is printed) means "no overrides".
local pageTexts
local function loadPageTexts()
    if pageTexts == nil then
        pageTexts = {}
        local ok, found = pcall(require, ROOT .. ".ui.page_texts")
        if ok and type(found) == "table" then
            pageTexts = found
        elseif not ok and not tostring(found):find("not found", 1, true) then
            print("[ultimate_ui] ui/page_texts.lua could not be loaded: " .. tostring(found))
        end
    end
    return pageTexts
end

function widgets.pageTexts() return loadPageTexts() end

-- target -> { text =, color = } as the CODE wrote it (before page_texts.lua). The editor
-- compares against this to export only what really differs from the template.
widgets.defaults = setmetatable({}, { __mode = "k" })

local function giveOverrides(def, key, target)
    widgets.defaults[target] = { text = target.text, color = target.color, font = target.font }
    local mine = loadPageTexts()[def.id]
    local o = mine and mine[key]
    if type(o) == "table" then
        if type(o.text) == "string" then target.text = o.text end
        if o.color ~= nil then target.color = o.color end
        if type(o.font) == "string" then target.font = o.font end
    end
end

function widgets.textPage(spec)
    local def = { id = spec.id, file = spec.file, api = spec.api, textOnly = true, widgets = {} }
    local page = { def = def }
    local byId = {}

    for _, l in ipairs(spec.labels or {}) do
        local w = { id = l.id, type = "label", text = l.text, fontSize = l.fontSize or 30,
                    color = l.color or "rainbow", font = l.font, role = l.role }
        giveOverrides(def, w.id, w)
        def.widgets[#def.widgets + 1] = w
        byId[w.id] = w
    end

    -- One stack ("rows") holds every button / row label; items are created on first use.
    local stack = { id = "rows", type = "stack", size = { 0, 0 }, items = {} }
    def.widgets[#def.widgets + 1] = stack
    local byKey = {}

    function page.label(id) return byId[id] end

    function page.item(key, default)
        local it = byKey[key]
        if not it then
            it = { text = default, key = key }
            giveOverrides(def, "rows#" .. key, it)
            byKey[key] = it
            stack.items[#stack.items + 1] = it
            def.pending = true        -- the editor applies its saved edits to the new item
        end
        return it
    end

    -- Color of an item / label in 0-255. "rainbow" (or no color) gives the caller's r, g, b.
    function page.rgb(entry, r, g, b)
        local c = entry and entry.color
        if type(c) == "table" then return c[1] * 255, c[2] * 255, c[3] * 255 end
        return r, g, b
    end

    -- Tell the editor what was drawn. `items` is a list of
    --   { kind = "label", id = "title", text, fontSize, x, y, w, h, color }          (a label)
    --   { kind = "button", id = "rows", key = <row key>, text, x, y, w, h, color }   (a button / row)
    -- in screen pixels (the hit box the editor outlines). Cheap: one table per frame.
    function page.report(items, screenWidth, screenHeight, uiScale)
        widgets.last = { def = def, items = items, uiScale = uiScale,
                         width = screenWidth, height = screenHeight, time = love.timer.getTime() }
    end

    local replaced = false
    for i, s in ipairs(widgets.screens) do
        if s.id == def.id then widgets.screens[i] = def replaced = true end
    end
    if not replaced then widgets.screens[#widgets.screens + 1] = def end
    return page
end

return widgets
