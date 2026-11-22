-- ultimate_ui/ui/menu_background.lua  (the shared menu background)
-- Exported from the sandbox editor on 2026-11-21 23:42.
--
-- DROP-IN: copy this file over ultimate_ui/ui/menu_background.lua. Every menu page draws this picture, in plain
-- `love .` too. `return nil` = no background. config.menuBackground, if set, wins over this file.
-- Ship the image with your game.

return {
    dim = 0.3,
    image = "ultimate_ui/background/test_background_16x9.png",
    blur = 8,
}
