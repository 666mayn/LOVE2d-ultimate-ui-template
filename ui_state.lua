-- ui_state.lua
-- Menu navigation / pause / screen-flag state. Deliberately has zero
-- knowledge of your gameplay -- it only tracks which screen is showing and
-- menu cursor positions, so menu flow changes can't accidentally touch
-- gameplay state and vice versa.

local ui_state = {}

local DEFAULTS = {
    gamePaused = false,
    showMainMenu = true,
    showSettings = false,
    settingsSelection = 1,
    showKeyboardMenu = false,
    keyboardSelection = 1,
    showControllerMenu = false,
    controllerSelection = 1,
    showOtherSettingsMenu = false,
    otherSettingsSelection = 1,
    showTextureFilterMenu = false,
    textureFilterSelection = 1,
    menuSelection = 1,
    pauseSelection = 1,
    pulseTime = 0,
}

local state = {}
for k, v in pairs(DEFAULTS) do state[k] = v end

function ui_state.getState() return state end

function ui_state.init()
    for k, v in pairs(DEFAULTS) do state[k] = v end
end

-- Called every frame; just accumulates the menu "pulse" animation clock.
function ui_state.update(dt)
    state.pulseTime = state.pulseTime + dt
end

-- Enter the actual game screen (called once loading finishes).
function ui_state.enterPlayScreen()
    state.showMainMenu = false
    state.gamePaused = false
    state.showSettings = false
    state.showKeyboardMenu = false
    state.showControllerMenu = false
    state.showOtherSettingsMenu = false
    state.showTextureFilterMenu = false
end

-- Single source of truth for "go back to the main menu" from anywhere
-- (pause, game over, ...). Clears every screen flag that could otherwise be
-- left true alongside showMainMenu, which would keep an overlay rendering
-- (and accepting clicks) underneath the main menu.
function ui_state.exitToMainMenu()
    state.showMainMenu = true
    state.gamePaused = false
    state.showSettings = false
    state.showKeyboardMenu = false
    state.showControllerMenu = false
    state.showOtherSettingsMenu = false
    state.showTextureFilterMenu = false
end

return ui_state
