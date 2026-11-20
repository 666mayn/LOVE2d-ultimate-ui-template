-- main.lua
-- Demo wiring for the template. Everything between the "YOUR GAME" markers
-- is a throwaway toy (a checkerboard square you move with the bound keys)
-- -- delete it and drop in your own game. The rest shows how the menus,
-- settings, rebinding, texture filter and loading screen plug together.

local ui = require("ui")
local ui_state = require("ui_state")
local config = require("config")
local audio = require("audio")
local fonts = require("fonts")
local keybinds = require("keybinds")
local controller = require("controller")
local input = require("input")
local other_settings = require("other_settings")
local texture_filter_manager = require("texture_filter_manager")
local loading_screen = require("loading_screen")
local intro_sequence = require("intro_sequence")
local menu_input = require("menu_input")

local uiScale = 1

-- Everything is laid out relative to a 1080p reference height.
local function updateUIScale()
    local _, h = love.graphics.getDimensions()
    uiScale = math.max(0.5, math.min(2, h / 1080))
end

-- ==========================================
-- YOUR GAME (demo) -- replace me
-- ==========================================
local game = {}

local function gameLoad()
    -- An 8x8 checkerboard, made in code so the template needs no assets.
    -- Created through the manager so Settings -> Texture Filter changes it live.
    local data = love.image.newImageData(8, 8)
    for y = 0, 7 do
        for x = 0, 7 do
            local on = (x + y) % 2 == 0
            data:setPixel(x, y, on and 1 or 0.15, on and 0.8 or 0.15, on and 0.2 or 0.35, 1)
        end
    end
    game.texture = texture_filter_manager.newImage(data)
    game.x, game.y = 200, 200
    game.score = 0
    game.jumps = 0
end

local function gameUpdate(dt)
    local speed = input.isDown("placeholder_sprint") and 420 or 220
    if input.isDown("placeholder_forward")  then game.y = game.y - speed * dt end
    if input.isDown("placeholder_backward") then game.y = game.y + speed * dt end
    if input.isDown("placeholder_left")     then game.x = game.x - speed * dt end
    if input.isDown("placeholder_right")    then game.x = game.x + speed * dt end
    game.score = game.score + dt
end

local function gameKeypressed(key)
    if input.pressedKey("placeholder_jump", key) then game.jumps = game.jumps + 1 end
end

local function gameGamepadpressed(button)
    if input.pressedButton("placeholder_jump", button) then game.jumps = game.jumps + 1 end
end

local function gameDraw(w, h)
    local size = 96 * uiScale
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(game.texture, game.x * uiScale, game.y * uiScale, 0,
        size / game.texture:getWidth(), size / game.texture:getHeight())

    ui.drawSidePanel({
        { "TIME", string.format("%.1f", game.score) },
        { "JUMPS", game.jumps },
        { "FILTER", string.upper(texture_filter_manager.getActive().id) },
    }, 40 * uiScale, 140 * uiScale, uiScale)

    love.graphics.setFont(ui.getFont(18 * uiScale))
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf("Move with your bound keys -- [Esc] to pause", 0, h - 50 * uiScale, w, "center")
end
-- ==========================================
-- END YOUR GAME
-- ==========================================

function love.load()
    love.graphics.setBackgroundColor(0.06, 0.06, 0.09)

    -- Order matters: the filter first, so anything created afterwards
    -- (fonts excluded) already uses the saved mode.
    texture_filter_manager.init()
    fonts.load()
    keybinds.init()
    controller.init()
    other_settings.init()
    ui_state.init()
    loading_screen.init()
    updateUIScale()

    gameLoad()

    -- Loading screen: PLAY -> short load -> enter the game.
    loading_screen.configure({
        onFinish = function(target)
            if target == "game" then
                ui_state.enterPlayScreen()
            end
        end,
    })

    -- Hook menu actions up to your game.
    menu_input.configure({
        onPlay = function()
            loading_screen.start("game", 1.0, "LOADING...")
        end,
        onResume = function()
            ui_state.getState().gamePaused = false
        end,
        onExitToMenu = function()
            ui_state.exitToMainMenu()
            ui.resetPopupAnimation("mainMenu")
        end,
        -- onExit defaults to love.event.quit()
    })

    -- Optional startup videos (config.introVideos). Empty list = skipped.
    intro_sequence.start(config.introVideos, function()
        -- Intro finished (or none): good place to start menu music, e.g.
        -- audio.playMusic("music/menu.ogg")
        ui.resetPopupAnimation("mainMenu")
    end)
end

function love.resize()
    updateUIScale()
end

function love.update(dt)
    ui_state.update(dt)

    if intro_sequence.isActive() then
        intro_sequence.update(dt)
        return
    end
    if loading_screen.update(dt) then return end

    local s = ui_state.getState()
    local inGame = not s.showMainMenu and not s.gamePaused and not menu_input.getCurrentScreenName()
    if inGame and not menu_input.isCapturing() then
        gameUpdate(dt)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()

    if intro_sequence.isActive() then
        intro_sequence.draw(w, h, uiScale)
        return
    end

    local ls = loading_screen.getState()
    if ls.isLoading then
        ui.drawLoadingScreen(w, h, uiScale, ls.loadTimer, ls.loadTimerMax, ls.loadLabel)
        return
    end

    local s = ui_state.getState()
    local mx, my = love.mouse.getPosition()

    -- World + HUD (behind the menus; hidden while the main menu is up).
    if not s.showMainMenu then
        gameDraw(w, h)
        ui.drawGameTitle(w, uiScale)
    end
    ui.drawVersionText(w, h, uiScale)
    ui.drawFPS(uiScale)

    -- Menus: only the top-most screen draws (same priority as menu_input.lua).
    if s.showTextureFilterMenu then
        ui.drawTextureFilterMenu(w, h, s.textureFilterSelection, mx, my, uiScale)
    elseif s.showOtherSettingsMenu then
        ui.drawOtherSettingsMenu(w, h, s.otherSettingsSelection, mx, my, uiScale)
    elseif s.showControllerMenu then
        ui.drawControllerMenu(w, h, s.controllerSelection, mx, my, uiScale)
    elseif s.showKeyboardMenu then
        ui.drawKeyboardMenu(w, h, s.keyboardSelection, mx, my, uiScale)
    elseif s.showSettings then
        ui.drawSettingsMenu(w, h, s.settingsSelection, mx, my, uiScale)
    elseif s.gamePaused then
        ui.drawPauseMenu(w, h, s.pauseSelection, mx, my, uiScale)
    elseif s.showMainMenu then
        ui.drawMainMenu(w, h, s.menuSelection, mx, my, uiScale)
    end
end

function love.keypressed(key)
    if intro_sequence.isActive() then intro_sequence.skip() return end
    if loading_screen.getState().isLoading then return end
    if not menu_input.keypressed(key) then gameKeypressed(key) end
end

function love.mousepressed(x, y, button)
    if intro_sequence.isActive() then intro_sequence.skip() return end
    if loading_screen.getState().isLoading then return end
    local w, h = love.graphics.getDimensions()
    menu_input.mousepressed(x, y, button, w, h, uiScale)
end

function love.gamepadpressed(_, button)
    if intro_sequence.isActive() then intro_sequence.skip() return end
    if loading_screen.getState().isLoading then return end
    if not menu_input.gamepadpressed(button) then gameGamepadpressed(button) end
end

-- ==========================================
-- DEV SANDBOX (optional)
-- Run `love . --sandbox` for screen-jumping, a fake gamepad, auto-reload and
-- more (see sandbox/README.md). Without the flag this does nothing. Safe
-- to leave out of release builds: delete the sandbox/ folder (this block then skips itself).
-- ==========================================
if love.filesystem.getInfo("sandbox/init.lua") then
    local sandbox = require("sandbox")
    if sandbox.requested(arg) then sandbox.attach() end
end
