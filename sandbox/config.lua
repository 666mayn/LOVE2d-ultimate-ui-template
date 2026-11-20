-- sandbox/config.lua
-- Everything you might want to tweak about the dev sandbox lives here.
-- This file is plain data: change a key, a preset, or a default and restart.

return {
    -- On launch, jump back to the screen / window size you left off at.
    -- (Remembered in the save folder as sandbox_session.txt.)
    restoreOnLaunch = true,

    -- Skip config.introVideos while developing -- nobody wants a 10s intro
    -- on every reload.
    skipIntro = true,

    -- Watch every .lua file in the project; when one changes on disk, restart
    -- the game and land back on the same screen. F6 toggles it at runtime.
    autoReload = true,
    watchInterval = 0.5,                           -- seconds between disk checks
    watchIgnore = { ".git", "fonts" },             -- folders never scanned

    -- Window sizes F2 cycles through (anything bigger than your desktop is
    -- skipped). Good for checking the uiScale math at awkward aspect ratios.
    presets = {
        { 1280, 720 },   -- 16:9 default
        { 1920, 1080 },  -- uiScale 1.0, the layout reference
        { 1024, 768 },   -- 4:3
        { 800, 600 },    -- small 4:3
        { 1680, 720 },   -- ultrawide-ish
        { 640, 360 },    -- the minimum conf.lua allows
    },

    -- Hotkeys. Each action can have several keys (LOVE KeyConstants).
    -- They are ignored while a keyboard rebind is waiting for a key, so you
    -- can still bind F-keys in the Keyboard menu without triggering these.
    keys = {
        panel   = { "f1", "`" },
        resize  = { "f2" },
        pad     = { "f3" },
        log     = { "f4" },
        restart = { "f5" },
        reload  = { "f6" },
        loading = { "f7" },
        wipe    = { "f8" },
        saveDir = { "f9" },
        hide    = { "f10" },
        shot    = { "f12" },
    },

    -- While the F1 panel is open these number keys jump straight to a screen.
    -- Ids: main, pause, settings, keyboard, controller, other, texture, game
    jump = {
        ["1"] = "main",
        ["2"] = "pause",
        ["3"] = "settings",
        ["4"] = "keyboard",
        ["5"] = "controller",
        ["6"] = "other",
        ["7"] = "texture",
        ["8"] = "game",
    },

    -- Virtual gamepad (F3): which keyboard key stands in for which button.
    -- Keys not listed here still act as normal keyboard input.
    padMap = {
        up = "dpup", down = "dpdown", left = "dpleft", right = "dpright",
        z = "a", x = "b", c = "x", v = "y",
        q = "leftshoulder", e = "rightshoulder",
        ["return"] = "start", tab = "back",
    },

    -- Files F8 deletes from the save folder (the template's own settings).
    -- Deliberately a fixed list: if you run the sandbox inside your real
    -- game, it must never touch your game's saves. Add your own if you want.
    saveFiles = {
        "keybinds.txt",
        "controller.txt",
        "other_settings.txt",
        "texture_filter_choice.txt",
        "crt_filter_choice.txt",
    },
}
