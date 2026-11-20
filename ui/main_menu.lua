-- ui/main_menu.lua  (screen "mainMenu")
-- Main menu screen. Described as DATA (see ui/widgets.lua for the format);
-- the widget renderer does the drawing, hover and click handling.
--
-- This file is exactly what the sandbox editor exports, so you can edit it by hand
-- OR tweak it in the editor (love . --sandbox, F11, Ctrl+E) and drop the result
-- from exports/ui/ back over it.
--
-- Row order == menuSelection index (menu_input.lua relies on this).
-- To add a button: add { text = "...", action = "..." } to the stack below, then handle
-- the new action string in menu_input.lua's main-menu handler. Layout is
-- parametric on the number of items, so nothing else needs to change.
-- `gapBefore` adds extra space above an item (EXIT gets a little breathing room).
-- In text, {config.title} pulls a live value from config.lua; showIf = "config.subtitle"
-- hides the subtitle while config.subtitle is "".
local widgets = require("ui.widgets")

local screen = {
    id   = "mainMenu",
    file = "ui/main_menu.lua",
    api  = "MainMenu",
    dim  = 180 / 255,
    widgets = {
        { id = "buttons", type = "stack", size = { 400, 60 }, spacing = 20,
          color = "rainbow", pop = { delay = 0.18, stagger = 0.08, duration = 0.4 },
          items = {
              { text = "P L A Y",         action = "play" },
              { text = "S E T T I N G S", action = "settings" },
              { text = "E X I T",         action = "exit", gapBefore = 15 },
          } },

        -- Title sits a fixed distance above the button block (so it follows the
        -- block no matter how many rows you add) and pops in first.
        { id = "title", type = "label", text = "{config.title}",
          fontSize = 72, color = "rainbow", relativeTo = "buttons", offset = { 0, -150 },
          pop = { delay = 0, duration = 0.5 } },

        -- Optional subtitle (config.subtitle = "" turns it off)
        { id = "subtitle", type = "label", text = "{config.subtitle}",
          fontSize = 34, color = { 1, 0.76, 0.12 }, relativeTo = "title", offset = { 0, 84 },
          pop = { delay = 0.1, duration = 0.5 }, showIf = "config.subtitle" },
    },
}

return widgets.screenModule(screen)
