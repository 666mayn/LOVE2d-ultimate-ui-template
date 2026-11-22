-- ui/menu_background.lua
-- The ONE background picture every menu page shows (main, pause, settings, keyboard, controller,
-- other, textures, loading), in plain `love .` as well as the sandbox. The sandbox editor writes this
-- file when you export (Ctrl+E / Ctrl+Shift+E); you can also edit it by hand.
--
--   image  path from the game root (png / jpg); scaled to cover the screen
--   blur   0 (sharp) .. 10      dim  0..1 black overlay on top
--
-- `return nil` = no background. config.menuBackground, if you set it, wins over this file.
-- Ship the image with your game (the bundled one is a placeholder: see background/LICENSE.md).
return {
    image = "ultimate_ui/background/test_background_16x9.png",
    blur = 8,
    dim = 0.3,
}
