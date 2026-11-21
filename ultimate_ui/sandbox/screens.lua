-- sandbox/screens.lua
-- Jump straight to any screen without clicking through the menus.
--
-- The menus are driven by boolean flags in ui_state.lua (top-most flag wins,
-- see menu_input.lua). To land on e.g. Keyboard "the way a player would",
-- we raise the whole chain -- pause (or main) -> settings -> keyboard -- so
-- BACK / Esc walks out through the real parents instead of dropping you
-- into nothing.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui = require(ROOT .. ".ui")
local ui_state = require(ROOT .. ".ui_state")
local menu_input = require(ROOT .. ".menu_input")
local keybinds = require(ROOT .. ".keybinds")
local controller = require(ROOT .. ".controller")
local loading_screen = require(ROOT .. ".loading_screen")

local screens = {}

-- Flags raised (outermost first) for screens that sit on top of main/pause.
local CHAIN = {
    settings   = { "showSettings" },
    keyboard   = { "showSettings", "showKeyboardMenu" },
    controller = { "showSettings", "showControllerMenu" },
    other      = { "showSettings", "showOtherSettingsMenu" },
    texture    = { "showSettings", "showTextureFilterMenu" },
}

-- flag -> cursor field in ui_state / popup-animation name
local CURSOR = {
    showMainMenu = "menuSelection", gamePaused = "pauseSelection",
    showSettings = "settingsSelection", showKeyboardMenu = "keyboardSelection",
    showControllerMenu = "controllerSelection", showOtherSettingsMenu = "otherSettingsSelection",
    showTextureFilterMenu = "textureFilterSelection",
}
local POPUP = {
    showMainMenu = "mainMenu", gamePaused = "pauseMenu",
    showSettings = "settingsMenu", showKeyboardMenu = "keyboardMenu",
    showControllerMenu = "controllerMenu", showOtherSettingsMenu = "otherSettingsMenu",
    showTextureFilterMenu = "textureFilterMenu",
}

-- menu_input.getCurrentScreenName() -> our id
local NAME_TO_ID = {
    textureFilter = "texture", otherSettings = "other", controller = "controller",
    keyboard = "keyboard", settings = "settings", pause = "pause", main = "main",
}
-- id -> the flag that screen is "owned" by (for reading its cursor)
local ID_TO_FLAG = {
    main = "showMainMenu", pause = "gamePaused", settings = "showSettings",
    keyboard = "showKeyboardMenu", controller = "showControllerMenu",
    other = "showOtherSettingsMenu", texture = "showTextureFilterMenu",
}

function screens.isValid(id)
    return id == "main" or id == "pause" or id == "game" or CHAIN[id] ~= nil
end

-- Which screen is on top right now: an id above, or "game" if none is.
function screens.currentId()
    local name = menu_input.getCurrentScreenName()
    return name and NAME_TO_ID[name] or "game"
end

-- Where a sub-screen would be opened from: "main" if the main menu is up,
-- otherwise "pause" (i.e. you're in-game).
function screens.base()
    return ui_state.getState().showMainMenu and "main" or "pause"
end

-- Cursor row of the current screen (nil when in-game).
function screens.cursor()
    local flag = ID_TO_FLAG[screens.currentId()]
    return flag and ui_state.getState()[CURSOR[flag]] or nil
end

-- Jump to `id`. `base` ("main" | "pause") picks which parent a sub-screen
-- hangs off; defaults to wherever you are now.
function screens.jump(id, base)
    if not screens.isValid(id) then return false end
    local s = ui_state.getState()
    base = base or screens.base()

    -- Cancel anything half-finished so the jump lands cleanly.
    keybinds.cancelCapture()
    controller.cancelCapture()
    loading_screen.init()

    if id == "game" then
        ui_state.enterPlayScreen()
        return true
    end

    local fromMain = (id == "main") or (CHAIN[id] ~= nil and base == "main")
    if fromMain then
        ui_state.exitToMainMenu()
        s.menuSelection = 1
        ui.resetPopupAnimation(POPUP.showMainMenu)
    else
        ui_state.enterPlayScreen()
        s.gamePaused = true
        s.pauseSelection = 1
        ui.resetPopupAnimation(POPUP.gamePaused)
    end

    for _, flag in ipairs(CHAIN[id] or {}) do
        s[flag] = true
        s[CURSOR[flag]] = 1
        ui.resetPopupAnimation(POPUP[flag])
    end
    return true
end

return screens
