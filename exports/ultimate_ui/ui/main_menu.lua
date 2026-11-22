-- ultimate_ui/ui/main_menu.lua  (screen "mainMenu")
-- Exported from the sandbox editor on 2026-11-21 23:42.
--
-- DROP-IN: copy this file over ultimate_ui/ui/main_menu.lua in your project. Nothing else has to
-- change -- it provides the functions ui/init.lua and menu_input.lua already call
-- (drawMainMenu, handleMainMenuClick, getRowCount, getActionAt).
--
-- It is plain data: edit it by hand, or tweak it again in the editor (love . --sandbox,
-- F11, Ctrl+E). To add a button, add { text = "...", action = "..." } to a stack and
-- handle the action in menu_input.lua. In text, {config.title} pulls a live value;
-- showIf = "config.subtitle" hides a widget while that value is empty. See ui/widgets.lua.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local widgets = require(ROOT .. ".ui.widgets")

local screen = {
    id = "mainMenu",
    file = "ui/main_menu.lua",
    api = "MainMenu",
    dim = 0.705882,
    widgets = {
        {
            id = "buttons",
            type = "stack",
            color = "rainbow",
            size = { 400, 60 },
            spacing = 20,
            pop = {
                delay = 0.18,
                stagger = 0.08,
                duration = 0.4,
            },
            items = {
                {
                    text = "TEST PLAY",
                    action = "play",
                    color = "rainbow",
                },
                {
                    text = "TEST SETTINGS",
                    action = "settings",
                },
                {
                    text = "TEST EXIT",
                    action = "exit",
                    gapBefore = 15,
                },
            },
        },
        {
            id = "title",
            type = "label",
            text = "TEST TITLE",
            fontSize = 72,
            color = "rainbow",
            relativeTo = "buttons",
            offset = { 0, -150 },
            pop = {
                delay = 0,
                duration = 0.5,
            },
        },
        {
            id = "subtitle",
            type = "label",
            text = "{config.subtitle}",
            fontSize = 34,
            color = { 1, 0.76, 0.12 },
            relativeTo = "title",
            offset = { 0, 84 },
            showIf = "config.subtitle",
            pop = {
                delay = 0.1,
                duration = 0.5,
            },
        },
    },
}

return widgets.screenModule(screen)
