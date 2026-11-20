-- ui/init.lua
-- Package entry point for the ui/ folder.
--
-- Lua's require() resolves require("ui") to ui/init.lua when there's no
-- ui.lua at the top level, so game code just does `local ui = require("ui")`
-- and calls `ui.drawXyz(...)`. This file re-assembles the public API out of
-- the split-up submodules below.
local ui = {}

local helpers             = require("ui.helpers")
local hud                 = require("ui.hud")
local main_menu           = require("ui.main_menu")
local pause_menu          = require("ui.pause_menu")
local loading_screen      = require("ui.loading_screen")
local settings_menu       = require("ui.settings_menu")
local keyboard_menu       = require("ui.keyboard_menu")
local controller_menu     = require("ui.controller_menu")
local other_settings_menu = require("ui.other_settings_menu")
local texture_filter_menu = require("ui.texture_filter_menu")

-- Popup pop-in animation control (call on open events, e.g.
-- ui.resetPopupAnimation("settingsMenu") when a menu is opened)
ui.resetPopupAnimation = helpers.resetPopupAnimation

-- Font lookup used by every screen (fonts.lua under the hood)
ui.getFont = helpers.getFont

-- HUD (ui/hud.lua)
ui.drawVersionText = hud.drawVersionText
ui.drawFPS         = hud.drawFPS
ui.drawSidePanel   = hud.drawSidePanel
ui.drawGameTitle   = hud.drawGameTitle

-- Main menu (ui/main_menu.lua)
ui.drawMainMenu        = main_menu.drawMainMenu
ui.handleMainMenuClick = main_menu.handleMainMenuClick
ui.getMainMenuRowCount = main_menu.getRowCount
ui.getMainMenuActionAt = main_menu.getActionAt

-- Pause menu (ui/pause_menu.lua)
ui.drawPauseMenu        = pause_menu.drawPauseMenu
ui.handlePauseMenuClick = pause_menu.handlePauseMenuClick
ui.getPauseRowCount     = pause_menu.getRowCount
ui.getPauseActionAt     = pause_menu.getActionAt

-- Loading screen (ui/loading_screen.lua)
ui.drawLoadingScreen = loading_screen.drawLoadingScreen

-- Settings menu (ui/settings_menu.lua)
ui.drawSettingsMenu        = settings_menu.drawSettingsMenu
ui.handleSettingsMenuClick = settings_menu.handleSettingsMenuClick
ui.getSettingsRowCount     = settings_menu.getRowCount
ui.getSettingsActionAt     = settings_menu.getActionAt

-- Keyboard menu (ui/keyboard_menu.lua) -- one level below Settings
ui.drawKeyboardMenu        = keyboard_menu.drawKeyboardMenu
ui.handleKeyboardMenuClick = keyboard_menu.handleKeyboardMenuClick
ui.getKeyboardRowCount     = keyboard_menu.getRowCount
ui.getKeyboardRowAt        = keyboard_menu.getRowAt

-- Controller menu (ui/controller_menu.lua) -- sibling of the keyboard menu
ui.drawControllerMenu        = controller_menu.drawControllerMenu
ui.handleControllerMenuClick = controller_menu.handleControllerMenuClick
ui.getControllerRowCount     = controller_menu.getRowCount
ui.getControllerRowAt        = controller_menu.getRowAt

-- Other Settings menu (ui/other_settings_menu.lua) -- sibling of the above
ui.drawOtherSettingsMenu        = other_settings_menu.drawOtherSettingsMenu
ui.handleOtherSettingsMenuClick = other_settings_menu.handleOtherSettingsMenuClick
ui.getOtherSettingsRowCount     = other_settings_menu.getRowCount
ui.getOtherSettingsRowAt        = other_settings_menu.getRowAt

-- Texture Filter menu (ui/texture_filter_menu.lua) -- sibling of the above
ui.drawTextureFilterMenu        = texture_filter_menu.drawTextureFilterMenu
ui.handleTextureFilterMenuClick = texture_filter_menu.handleTextureFilterMenuClick
ui.getTextureFilterRowCount     = texture_filter_menu.getRowCount
ui.getTextureFilterRowAt        = texture_filter_menu.getRowAt
ui.activateTextureFilterRow     = texture_filter_menu.activateRow

return ui
