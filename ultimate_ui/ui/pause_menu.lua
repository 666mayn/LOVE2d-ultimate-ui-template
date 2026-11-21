-- ui/pause_menu.lua  (screen "pauseMenu")
-- Pause menu screen. Described as DATA (see ui/widgets.lua for the format); the widget
-- renderer does the drawing, hover and click handling -- and the sandbox editor (F11) can
-- edit its title / button text and colors, then export this file.
--
-- Row order == pauseSelection index (menu_input.lua relies on this).
-- To add a button: add { text = "...", action = "..." } to the stack below, then handle
-- the new action string in menu_input.lua's pause handler (doPause).
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local widgets = require(ROOT .. ".ui.widgets")

local screen = {
    id   = "pauseMenu",
    file = "ui/pause_menu.lua",
    api  = "PauseMenu",
    dim  = 180 / 255,
    widgets = {
        { id = "buttons", type = "stack", size = { 400, 60 }, spacing = 20,
          color = "rainbow", pop = { delay = 0.18, stagger = 0.08, duration = 0.4 },
          items = {
              { text = "RESUME",       action = "resume" },
              { text = "SETTINGS",     action = "settings" },
              { text = "EXIT TO MENU", action = "exit_to_menu" },
          } },

        -- Title sits a fixed distance above the button block and pops in first.
        { id = "title", type = "label", text = "PAUSED",
          fontSize = 60, color = "rainbow", relativeTo = "buttons", offset = { 0, -100 },
          pop = { delay = 0, duration = 0.5 } },
    },
}

return widgets.screenModule(screen)
