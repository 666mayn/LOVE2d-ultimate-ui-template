-- menu_input.lua
-- Keyboard / mouse / gamepad navigation for every menu screen, in one place.
-- main.lua forwards love.keypressed / love.mousepressed / love.gamepadpressed
-- here; this file decides which screen is on top, moves the cursor, runs the
-- activated row, and drives the rebind captures for keybinds.lua and
-- controller.lua.
--
-- Screen priority (top wins), resolved from the flags in ui_state.lua:
--   texture filter > other settings > controller > keyboard > settings
--   > pause > main menu > (none: you're in the game)
-- Because the top-most flag wins, closing a sub-menu naturally reveals
-- whichever screen it was opened from -- no "return to" bookkeeping needed.
--
-- Menu controls: Up/Down + Enter, mouse click, D-pad + A. Esc / B go back.
-- Esc / Start pause during gameplay.
--
-- Hook your game in with menu_input.configure{ onPlay=, onResume=,
-- onExitToMenu=, onExit= } -- see main.lua.

local ROOT = (...):match("^(.*)%.[^.]+$")
local ui = require(ROOT .. ".ui")
local ui_state = require(ROOT .. ".ui_state")
local keybinds = require(ROOT .. ".keybinds")
local controller = require(ROOT .. ".controller")
local other_settings = require(ROOT .. ".other_settings")

local menu_input = {}

local state = ui_state.getState()

local hooks = {
    onPlay = function() ui_state.enterPlayScreen() end,
    onResume = function() state.gamePaused = false end,
    onExitToMenu = function() ui_state.exitToMainMenu() end,
    onExit = function() love.event.quit() end,
}

function menu_input.configure(opts)
    for k, v in pairs(opts or {}) do hooks[k] = v end
end

-- ==========================================
-- Screen helpers
-- ==========================================
local SCREENS -- forward declaration (screens reference each other)

local function currentScreen()
    for _, scr in ipairs(SCREENS) do
        if state[scr.flag] then return scr end
    end
    return nil
end

function menu_input.getCurrentScreenName()
    local scr = currentScreen()
    return scr and scr.name or nil
end

local function refreshPopup()
    local scr = currentScreen()
    if scr then ui.resetPopupAnimation(scr.popup) end
end

local function open(flag, selKey, popup)
    state[flag] = true
    state[selKey] = 1
    ui.resetPopupAnimation(popup)
end

local function close(flag)
    state[flag] = false
    refreshPopup() -- replay the pop-in of the screen we just returned to
end

function menu_input.openPause()
    if currentScreen() then return end
    open("gamePaused", "pauseSelection", "pauseMenu")
end

-- Turns a row from a menu's getRowAt() into the same table the menu's
-- click handler returns, so mouse and keyboard/gamepad share one code path.
local function rowToResult(row)
    if not row then return nil end
    if row.type == "keybind" then return { action = "rebind", id = row.id } end
    if row.type == "cycle" then return { action = "cycle", id = row.id } end
    return { action = row.id } -- "reset" / "back"
end

-- ==========================================
-- What each screen does when a row is chosen
-- ==========================================
local function doMain(action)
    if action == "play" then
        hooks.onPlay()
    elseif action == "settings" then
        open("showSettings", "settingsSelection", "settingsMenu")
    elseif action == "exit" then
        hooks.onExit()
    end
end

local function doPause(action)
    if action == "resume" then
        hooks.onResume()
    elseif action == "settings" then
        open("showSettings", "settingsSelection", "settingsMenu")
    elseif action == "exit_to_menu" then
        hooks.onExitToMenu()
    end
end

local function doSettings(action)
    if action == "keyboard" then
        open("showKeyboardMenu", "keyboardSelection", "keyboardMenu")
    elseif action == "controller" then
        open("showControllerMenu", "controllerSelection", "controllerMenu")
    elseif action == "other_settings" then
        open("showOtherSettingsMenu", "otherSettingsSelection", "otherSettingsMenu")
    elseif action == "texture_filter" then
        open("showTextureFilterMenu", "textureFilterSelection", "textureFilterMenu")
    elseif action == "back" then
        close("showSettings")
    end
end

local function doKeyboard(result)
    if not result then return end
    if result.action == "rebind" then
        keybinds.startCapture(result.id)
    elseif result.action == "reset" then
        keybinds.resetToDefaults()
    elseif result.action == "back" then
        close("showKeyboardMenu")
    end
end

local function doController(result)
    if not result then return end
    if result.action == "rebind" then
        controller.startCapture(result.id)
    elseif result.action == "reset" then
        controller.resetToDefaults()
    elseif result.action == "back" then
        close("showControllerMenu")
    end
end

local function doOther(result)
    if not result then return end
    if result.action == "cycle" then
        other_settings.cycle(result.id)
    elseif result.action == "reset" then
        other_settings.resetToDefaults()
    elseif result.action == "back" then
        close("showOtherSettingsMenu")
    end
end

local function doTextureFilter(result)
    if not result then return end
    if result.action == "back" then
        close("showTextureFilterMenu")
    elseif result.action == "select" then
        local row = ui.getTextureFilterRowAt(result.row)
        if ui.activateTextureFilterRow(row) == "back" then
            close("showTextureFilterMenu")
        end
    end
end

-- Each screen: which ui_state flag/cursor it uses, how to count its rows,
-- how to turn a mouse click or a cursor index into an action, and what BACK
-- does. Listed in priority order (top-most first).
SCREENS = {
    { name = "textureFilter", flag = "showTextureFilterMenu", sel = "textureFilterSelection", popup = "textureFilterMenu",
      count = ui.getTextureFilterRowCount,
      click = ui.handleTextureFilterMenuClick,
      activate = function(i)
          local row = ui.getTextureFilterRowAt(i)
          if row and row.type == "action" and row.id == "back" then
              doTextureFilter({ action = "back" })
          else
              doTextureFilter({ action = "select", row = i })
          end
      end,
      act = doTextureFilter,
      back = function() close("showTextureFilterMenu") end },

    { name = "otherSettings", flag = "showOtherSettingsMenu", sel = "otherSettingsSelection", popup = "otherSettingsMenu",
      count = ui.getOtherSettingsRowCount,
      click = ui.handleOtherSettingsMenuClick,
      activate = function(i) doOther(rowToResult(ui.getOtherSettingsRowAt(i))) end,
      act = doOther,
      back = function() close("showOtherSettingsMenu") end },

    { name = "controller", flag = "showControllerMenu", sel = "controllerSelection", popup = "controllerMenu",
      count = ui.getControllerRowCount,
      click = ui.handleControllerMenuClick,
      activate = function(i) doController(rowToResult(ui.getControllerRowAt(i))) end,
      act = doController,
      back = function() close("showControllerMenu") end },

    { name = "keyboard", flag = "showKeyboardMenu", sel = "keyboardSelection", popup = "keyboardMenu",
      count = ui.getKeyboardRowCount,
      click = ui.handleKeyboardMenuClick,
      activate = function(i) doKeyboard(rowToResult(ui.getKeyboardRowAt(i))) end,
      act = doKeyboard,
      back = function() close("showKeyboardMenu") end },

    { name = "settings", flag = "showSettings", sel = "settingsSelection", popup = "settingsMenu",
      count = ui.getSettingsRowCount,
      click = ui.handleSettingsMenuClick,
      activate = function(i) doSettings(ui.getSettingsActionAt(i)) end,
      act = doSettings,
      back = function() close("showSettings") end },

    { name = "pause", flag = "gamePaused", sel = "pauseSelection", popup = "pauseMenu",
      count = ui.getPauseRowCount,
      click = ui.handlePauseMenuClick,
      activate = function(i) doPause(ui.getPauseActionAt(i)) end,
      act = doPause,
      back = function() hooks.onResume() end },

    { name = "main", flag = "showMainMenu", sel = "menuSelection", popup = "mainMenu",
      count = ui.getMainMenuRowCount,
      click = ui.handleMainMenuClick,
      activate = function(i) doMain(ui.getMainMenuActionAt(i)) end,
      act = doMain,
      back = function() end }, -- nothing to go back to from the main menu
}

local function moveCursor(scr, dir)
    local count = scr.count()
    if count < 1 then return end
    state[scr.sel] = ((state[scr.sel] - 1 + dir) % count) + 1
end

-- True while a rebind is waiting for input; gameplay should ignore input then.
function menu_input.isCapturing()
    return keybinds.isCapturing() or controller.isCapturing()
end

-- ==========================================
-- Entry points called from main.lua
-- Each returns true if the event was consumed by the menus (so gameplay
-- should ignore it), false if no menu is open and it's yours to handle.
-- ==========================================
function menu_input.keypressed(key)
    if keybinds.isCapturing() then
        keybinds.handleKeyPressed(key)
        return true
    end
    if controller.isCapturing() then
        if key == "escape" then controller.cancelCapture() end
        return true
    end

    local scr = currentScreen()
    if not scr then
        if key == "escape" then menu_input.openPause() return true end
        return false
    end

    if key == "up" then
        moveCursor(scr, -1)
    elseif key == "down" then
        moveCursor(scr, 1)
    elseif key == "return" or key == "kpenter" then
        scr.activate(state[scr.sel])
    elseif key == "escape" then
        scr.back()
    end
    return true
end

function menu_input.mousepressed(x, y, button, screenWidth, screenHeight, uiScale)
    if button ~= 1 then return currentScreen() ~= nil end

    -- A click while waiting for a rebind just cancels it.
    if keybinds.isCapturing() then keybinds.cancelCapture() return true end
    if controller.isCapturing() then controller.cancelCapture() return true end

    local scr = currentScreen()
    if not scr then return false end
    scr.act(scr.click(x, y, screenWidth, screenHeight, uiScale))
    return true
end

function menu_input.gamepadpressed(button)
    if controller.isCapturing() then
        controller.handleGamepadPressed(button)
        return true
    end
    if keybinds.isCapturing() then return true end

    local scr = currentScreen()
    if not scr then
        if button == "start" then menu_input.openPause() return true end
        return false
    end

    if button == "dpup" then
        moveCursor(scr, -1)
    elseif button == "dpdown" then
        moveCursor(scr, 1)
    elseif button == "a" then
        scr.activate(state[scr.sel])
    elseif button == "b" then
        scr.back()
    elseif button == "start" and scr.name == "pause" then
        scr.back()
    end
    return true
end

return menu_input
