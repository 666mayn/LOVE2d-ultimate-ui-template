-- ultimate_ui/init.lua
-- The one entry point. Copy this whole folder into your project, then:
--
--     local UI = require("ultimate_ui")          -- or "libs.ultimate_ui", wherever you put it
--
-- Everything else hangs off that one table and is loaded the first time you touch
-- it (nothing is required, and no shader compiled, until it is used):
--
--     UI.init()                      -- in love.load: initialises every module, in the right order
--     UI.configure{ title = "..." }  -- override ultimate_ui/config.lua values from your own code
--     UI.ui.drawMainMenu(...)        -- the draw / click API (ui/init.lua)
--     UI.state, UI.keybinds, UI.controller, UI.input, UI.audio, UI.sounds, UI.fonts, UI.config,
--     UI.menu_input, UI.other_settings, UI.textures, UI.crt, UI.loading, UI.intro, UI.log, UI.checks
--
-- Every module also works under its file name (UI.ui_state, UI.crt_manager, ...), and
-- can be required directly: require("ultimate_ui.keybinds"). Because every file inside
-- the folder finds its siblings relative to its own module name, the folder can be
-- renamed or moved without editing anything.
--
-- Nothing is installed in the global namespace and nothing outside this folder is
-- touched, so it cannot collide with your own input.lua / audio.lua / config.lua / ui/.

local ROOT = ...
assert(type(ROOT) == "string",
    "ultimate_ui: load this folder with require(), e.g. require(\"ultimate_ui\")")

local DIR = (ROOT:gsub("%.", "/"))   -- filesystem path of this folder, from the game root

local UI = {
    root = ROOT,   -- module prefix, e.g. "ultimate_ui"
    dir  = DIR,    -- folder path,   e.g. "ultimate_ui"
}

-- friendly name -> module (relative to this folder)
local MODULES = {
    ui             = "ui",                       -- draw*/handle*Click/get* functions
    widgets        = "ui.widgets",               -- build your own data-driven screens
    state          = "ui_state",
    config         = "config",
    audio          = "audio",
    sounds         = "ui_sounds",                -- menu click + loading-screen sounds (sounds/ folder)
    fonts          = "fonts",
    keybinds       = "keybinds",
    controller     = "controller",
    input          = "input",
    menu_input     = "menu_input",
    other_settings = "other_settings",
    textures       = "texture_filter_manager",
    crt            = "crt_manager",
    loading        = "loading_screen",
    intro          = "intro_sequence",
    log            = "debuglog",
    checks         = "checks",                   -- startup self-check (run by UI.init)
    sandbox        = "sandbox",                  -- dev tool; see UI.hasSandbox()
}
-- the plain file names work too (UI.ui_state, UI.crt_manager, ...)
for _, mod in pairs({
    "ui_state", "texture_filter_manager", "crt_manager", "loading_screen",
    "intro_sequence", "debuglog", "ui_sounds",
}) do
    MODULES[mod] = mod
end

setmetatable(UI, {
    __index = function(t, key)
        local mod = MODULES[key]
        if not mod then return nil end
        local value = require(ROOT .. "." .. mod)
        rawset(t, key, value)
        return value
    end,
})

-- Path of something inside this folder, from the game root. Handy for pointing a
-- screen's background at a bundled image:  UI.path("background/my_image.png")
function UI.path(sub)
    return sub and (DIR .. "/" .. sub) or DIR
end

-- Overrides values in config.lua without editing it:
--     UI.configure{ title = "MY GAME", version = "v1.2.0", showFPS = true }
-- Call it before UI.init() (or any time: menus read config live).
function UI.configure(overrides)
    local config = UI.config
    for k, v in pairs(overrides or {}) do config[k] = v end
    return UI
end

-- Initialises every stateful module, in the order that matters: the texture filter
-- first so anything created afterwards (fonts excluded) already uses the saved mode.
-- Call once from love.load().
function UI.init()
    UI.textures.init()
    UI.crt.init()
    UI.fonts.load()
    UI.keybinds.init()
    UI.controller.init()
    UI.other_settings.init()
    UI.state.init()
    UI.loading.init()
    UI.sounds.refresh()  -- finds ui.* / loading.* (or the examples) in sounds/
    UI.checks.run()      -- warns (console + sandbox log) about missing image / fonts / filters ...
    return UI
end

-- True when the dev sandbox folder is present (delete <this folder>/sandbox before shipping).
function UI.hasSandbox()
    return love.filesystem.getInfo(DIR .. "/sandbox/init.lua") ~= nil
end

return UI
