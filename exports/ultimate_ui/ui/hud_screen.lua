-- ultimate_ui/ui/hud_screen.lua  (screen "hud")
-- Exported from the sandbox editor on 2026-11-21 23:42.
--
-- DROP-IN: copy this file over ultimate_ui/ui/hud_screen.lua in your project. Nothing else has to
-- change -- it provides the functions ui/init.lua and menu_input.lua already call
-- (drawHud, handleHudClick, getRowCount, getActionAt).
--
-- It is plain data: edit it by hand, or tweak it again in the editor (love . --sandbox,
-- F11, Ctrl+E). To add a button, add { text = "...", action = "..." } to a stack and
-- handle the action in menu_input.lua. In text, {config.title} pulls a live value;
-- showIf = "config.subtitle" hides a widget while that value is empty. See ui/widgets.lua.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local widgets = require(ROOT .. ".ui.widgets")

local screen = {
    id = "hud",
    file = "ui/hud_screen.lua",
    api = "Hud",
    widgets = {
        {
            id = "title",
            type = "label",
            text = "{config.title}",
            fontSize = 60,
            color = "rainbow",
            offset = { 0, 50 },
        },
        {
            id = "stats",
            type = "stats",
            fontSize = 30,
            color = "rainbow",
            items = {
                {
                    text = "RES",
                },
                {},
                {},
                {},
                {},
                {},
                {},
                {},
            },
            lineHeight = 40,
            x = 40,
            y = 140,
        },
    },
    static = true,
}

return widgets.screenModule(screen)
