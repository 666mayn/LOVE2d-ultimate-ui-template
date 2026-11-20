-- config.lua
-- One place for game-wide constants and the values the settings menus
-- write into. Rename the title, bump the version, add your own fields.
-- other_settings.lua rows point at fields on this table.

local config = {
    title    = "P L A C E H O L D E R   G A M E",  -- spaced caps match the menu style; plain text works too
    subtitle = "",                                  -- optional line under the main-menu title ("" = none)
    version  = "v0.1.0",

    -- Font: drop any .ttf / .otf into fonts/ and it is used automatically.
    -- Several in there? Name the one you want (file name inside fonts/); nil = first found.
    font = nil,                -- e.g. "myfont.ttf"

    -- Optional startup videos (.ogv) played back to back before the main menu.
    -- Leave empty to skip the intro entirely.
    introVideos = {},          -- e.g. { "intros/intro1.ogv", "intros/intro2.ogv" }

    -- Wired to Settings -> Other (see other_settings.lua)
    screenShakeIntensity = 1.0, -- multiply your shake magnitude by this (0 disables it)
    showFPS = false,            -- hud.drawFPS() only draws when this is true
    fullscreen = false,         -- mirrored by the FULLSCREEN row; conf.lua starts windowed
}

return config
