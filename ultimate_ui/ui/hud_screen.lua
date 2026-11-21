-- ui/hud_screen.lua  (screen "hud")
-- The in-game HUD: the floating game title and the stats side panel. Described as DATA
-- (see ui/widgets.lua) so the sandbox editor (F11) can edit their text and color while you
-- are IN the game, and export this file back out.
--
-- It is a `static` screen: it draws over the game with no menu backdrop and no pop-in.
-- The game draws it with ui.drawHUD(stats, w, h, uiScale) -- see ui/hud.lua and main.lua.
--
-- stats widget: the game supplies the rows ({ "LABEL", value } pairs) every frame. `items`
-- are optional per-row overrides: { text = "NEW LABEL", color = { r, g, b } } replaces that
-- row's label / color (the value always comes from the game). Keep a few empty {} entries
-- so every row can be selected in the editor.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local widgets = require(ROOT .. ".ui.widgets")

local screen = {
    id     = "hud",
    file   = "ui/hud_screen.lua",
    api    = "Hud",
    static = true,
    widgets = {
        -- Floating game title, top-center ({config.title} follows config.lua).
        { id = "title", type = "label", text = "{config.title}",
          fontSize = 60, color = "rainbow", offset = { 0, 50 } },

        -- Stats side panel, top-left.
        { id = "stats", type = "stats", x = 40, y = 140, lineHeight = 40, fontSize = 30,
          color = "rainbow",
          items = { {}, {}, {}, {}, {}, {}, {}, {} } },
    },
}

return widgets.screenModule(screen)
