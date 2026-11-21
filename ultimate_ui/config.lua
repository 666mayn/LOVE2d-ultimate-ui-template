-- config.lua
-- One place for game-wide constants and the values the settings menus
-- write into. Rename the title, bump the version, add your own fields.
-- other_settings.lua rows point at fields on this table.

local config = {
    title    = "P L A C E H O L D E R   G A M E",  -- spaced caps match the menu style; plain text works too
    subtitle = "",                                  -- optional line under the main-menu title ("" = none)
    version  = "v0.1.0",

    -- Font: drop any .ttf / .otf into ultimate_ui/fonts/ and it is used automatically.
    -- Several in there? Name the one you want (file name inside that folder); nil = first found.
    font = nil,                -- e.g. "myfont.ttf"

    -- Optional startup videos (.ogv) played back to back before the main menu.
    -- Leave empty to skip the intro entirely.
    introVideos = {},          -- e.g. { "intros/intro1.ogv", "intros/intro2.ogv" }

    -- ONE background picture shared by EVERY menu page (main, pause, settings, keyboard,
    -- controller, other, texture, loading), so it never drops out as you move between them.
    -- Path from the game root; scaled to cover the screen. blur 0 (sharp) .. 10, dim 0..1
    -- is the black overlay over the picture. nil = none (pages keep their plain dark overlay).
    -- A widget screen that sets its own `background` still overrides this for that page.
    menuBackground = nil,      -- e.g. { image = "ultimate_ui/background/my_image.png", blur = 8, dim = 0.3 }

    -- Startup self-check (checks.lua): at UI.init() it warns about a missing menu background
    -- image, no fonts, no screen filters, a missing intro video, an unwritable save folder ...
    -- Warnings print to the console (lovec.exe, or t.console = true) and the sandbox log (F4).
    startupChecks = true,

    -- Wired to Settings -> Other (see other_settings.lua)
    screenShakeIntensity = 1.0, -- multiply your shake magnitude by this (0 disables it)
    showFPS = false,            -- hud.drawFPS() only draws when this is true
    fullscreen = false,         -- mirrored by the FULLSCREEN row; conf.lua starts windowed
}

return config
