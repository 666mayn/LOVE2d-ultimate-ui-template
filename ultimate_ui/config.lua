-- config.lua
-- One place for game-wide constants and the values the settings menus
-- write into. Rename the title, bump the version, add your own fields.
-- other_settings.lua rows point at fields on this table.

local config = {
    title    = "P L A C E H O L D E R   G A M E",  -- spaced caps match the menu style; plain text works too
    subtitle = "",                                  -- optional line under the main-menu title ("" = none)
    version  = "v0.1.0",

    -- FONTS. Drop .ttf / .otf files anywhere under ultimate_ui/fonts/ (nested folders are fine) and
    -- they are all registered. UI.fonts.list() prints every name you can use below. A name can be a
    -- family folder ("pixeloid_sans"), a file name ("PixeloidSans-Bold" / "PixeloidSans-Bold.ttf"),
    -- or a path inside fonts/ -- case does not matter.
    --
    -- 1) Whole project at once: this font is used for ALL text (menus, HUD, sandbox). nil = the first
    --    font found.
    font = nil,                -- e.g. "boldpixels"

    -- 2) Per element type: override the font for one KIND of text; everything not listed keeps the
    --    project font above. Roles: title, subtitle (falls back to title), button, row (the
    --    key/controller/settings rows; falls back to button), hint, stat, hud (falls back to stat), body.
    fontRoles = {
        -- button = "pixeloid_sans",
        -- title  = "boldpixels",
        -- hint   = "player_sans_mono",
    },
    -- Text is centered in buttons / rows by measuring the font's capital letters, so every font
    -- lines up on its own. If one family still looks a hair high or low, nudge it here, in fractions
    -- of the font size (+ = down):  fontNudge = { fibberish = 0.05, player_sans_mono = -0.03 }
    fontNudge = {},

    -- 3) One single element: put  font = "fibberish"  on that widget / stack item in its ui/*.lua
    --    screen file (see ui/widgets.lua). It beats its role and the project font.

    -- BUTTON CORNERS. Rounded corners for every button / row in the menus, in 1080p reference pixels
    -- (scaled with the window like every other size). Ships at 12; 0 = square. A single button can override it with
    -- radius = 12 on its stack item in a ui/*.lua screen (or in ui/page_texts.lua for the hand-coded
    -- pages); the F11 editor's ROUND slider writes that for you. Anything above half the button's
    -- height just makes a pill.
    buttonRadius = 12,

    -- STARTUP INTRO. nil (or an empty list {}) = play every .ogv in ultimate_ui/intro_clips/ (nested
    -- folders fine, path order): replace the file, or add intro2.ogv, and that's it. A list of paths plays exactly those
    -- ({ "intros/a.ogv", "intros/b.ogv" }). false = no intro. Any key / click / button skips it.
    -- The game builds its menus (fonts, blurred background ...) while the intro plays.
    introVideos = nil,
    introSkipHint = false,     -- true shows "Press any key to skip" on the intro

    -- MOUSE CURSOR. Drop an image (.png / .jpg / .bmp / .tga) in ultimate_ui/cursor/ and it replaces
    -- the system cursor. Big images are shrunk to cursorSize px (longest side). cursorHotspot is the
    -- pixel that clicks, as fractions of the image: { 0, 0 } = top-left, { 0.5, 0.5 } = middle.
    -- cursor = false keeps the system cursor.
    cursor = true,
    cursorSize = 32,
    cursorHotspot = { 0.5, 0.5 },

    -- ONE background picture shared by EVERY menu page (main, pause, settings, keyboard,
    -- controller, other, texture, loading), so it never drops out as you move between them.
    -- Path from the game root; scaled to cover the screen. blur 0 (sharp) .. 10, dim 0..1
    -- is the black overlay over the picture. nil = none (pages keep their plain dark overlay).
    -- If nil, ui/menu_background.lua is used (the sandbox editor exports it). A widget screen that sets its own `background` still overrides this for that page.
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
