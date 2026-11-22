-- main.lua
-- Demo wiring for the template. Everything between the "YOUR GAME" markers
-- is a throwaway toy (a black-and-grey checkerboard on a 1920x1080 canvas that the bound keys scroll)
-- -- delete it and drop in your own game. The rest shows how the menus,
-- settings, rebinding, texture filter and loading screen plug together.
--
-- The whole UI system lives in the ultimate_ui/ folder and is pulled in with ONE
-- require. Modules load lazily the first time you touch them (UI.input, UI.audio, ...).

local UI = require("ultimate_ui")

local ui = UI.ui
local ui_state = UI.state
local config = UI.config
local input = UI.input
local menu_input = UI.menu_input
local texture_filter_manager = UI.textures
local crt_manager = UI.crt
local loading_screen = UI.loading
local intro_sequence = UI.intro
local sounds = UI.sounds
-- Also available (not used by this demo): UI.audio, UI.fonts, UI.keybinds,
-- UI.controller, UI.other_settings, UI.widgets, UI.log

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

-- The game world is drawn on ONE fixed-size canvas: 1920x1080 (16:9, a normal "1080p"
-- canvas). It is scaled to fit the window and centred, with bars on the sides or top
-- if the window is not 16:9. Change these two numbers if your game uses another size.
-- (The menus / HUD are separate: they are laid out at the window's size, see uiScale.)
local GAME_W, GAME_H = 1920, 1080
local CELL = 120                      -- checkerboard square size, in canvas pixels (16 x 9 squares)
local BLACK, GREY = 0.04, 0.30        -- the two checkerboard shades

local function gameLoad()
    -- Made through the manager, so Settings -> Textures (Sharp / Smooth / Hybrid) changes how
    -- the canvas is scaled to the window, live.
    game.canvas = texture_filter_manager.newCanvas(GAME_W, GAME_H)
    game.x, game.y = 0, 0             -- how far the board has scrolled (canvas pixels)
    game.score = 0
    game.jumps = 0
end

-- Placeholder world: a black-and-grey checkerboard filling the whole canvas.
-- The movement keys scroll it, so you can see input working. Replace with your game.
local function drawPlaceholderWorld()
    love.graphics.clear(BLACK, BLACK, BLACK, 1)
    love.graphics.setColor(GREY, GREY, GREY, 1)
    local cx, cy = math.floor(game.x / CELL), math.floor(game.y / CELL)
    local offX, offY = -(game.x % CELL), -(game.y % CELL)
    for row = 0, math.ceil(GAME_H / CELL) do
        for col = 0, math.ceil(GAME_W / CELL) do
            if (col + cx + row + cy) % 2 == 0 then
                love.graphics.rectangle("fill", offX + col * CELL, offY + row * CELL, CELL, CELL)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draws the world into game.canvas, then the canvas to the window at the largest size
-- that keeps 16:9 (letterboxed). Returns where it landed: x, y, scale.
local function drawGameCanvas(w, h)
    love.graphics.push("all")
    love.graphics.setCanvas(game.canvas)
    love.graphics.origin()
    drawPlaceholderWorld()
    love.graphics.pop()               -- back to whatever we were drawing to (the CRT canvas, if on)

    local scale = math.min(w / GAME_W, h / GAME_H)
    local x = math.floor((w - GAME_W * scale) / 2)
    local y = math.floor((h - GAME_H * scale) / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(game.canvas, x, y, 0, scale, scale)
    return x, y, scale
end

local function gameUpdate(dt)
    local speed = input.isDown("placeholder_sprint") and 800 or 400   -- canvas pixels / second
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
    drawGameCanvas(w, h)

    -- Game title + stats panel (ultimate_ui/ui/hud_screen.lua). Editable in the sandbox (F11).
    ui.drawHUD({
        { "CANVAS", GAME_W .. "x" .. GAME_H },
        { "TIME", string.format("%.1f", game.score) },
        { "JUMPS", game.jumps },
        { "FILTER", string.upper(texture_filter_manager.getActive().id) },
        { "CRT", string.upper(crt_manager.getActive().name) },
    }, w, h, uiScale)

    love.graphics.setFont(ui.getFont(18 * uiScale))
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf("Move with your bound keys -- [Esc] to pause", 0, h - 50 * uiScale, w, "center")
end
-- ==========================================
-- END YOUR GAME
-- ==========================================

function love.load()
    love.graphics.setBackgroundColor(0.06, 0.06, 0.09)

    -- Initialises every ultimate_ui module in the right order (the texture filter
    -- first, so anything created afterwards already uses the saved mode).
    -- Want to change the title / version / font? UI.configure{ title = "..." } here,
    -- or edit ultimate_ui/config.lua.
    UI.init()
    updateUIScale()

    gameLoad()

    -- Loading screen: PLAY -> load -> enter the game.
    -- The loading sound is ultimate_ui/sounds/loading.ogg (or .mp3 / .wav); until you add
    -- your own, the bundled example_loading.ogg plays. Menu clicks use ui.ogg the same way.
    loading_screen.configure({
        onStart = function(target)
            sounds.playLoading()
        end,
        onFinish = function(target)
            sounds.stopLoading()
            if target == "game" then
                ui_state.enterPlayScreen()
            end
        end,
    })

    -- Hook menu actions up to your game.
    menu_input.configure({
        onPlay = function()
            -- The screen lasts exactly as long as the loading sound (1.0s if there is none).
            loading_screen.start("game", sounds.loadingDuration(1.0), "LOADING...")
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
        -- UI.audio.playMusic("music/menu.ogg")
        ui.resetPopupAnimation("mainMenu")
    end)
end

function love.resize()
    updateUIScale()
end

function love.update(dt)
    ui_state.update(dt)
    crt_manager.update(dt) -- keeps the filter's animation running even in menus

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

local function drawScene()
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
        gameDraw(w, h)   -- world + title + stats (ui.drawHUD)
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

-- Everything drawn in drawScene() goes through the CRT filter chosen in
-- Settings -> Textures (a no-op when it's Off).
function love.draw()
    crt_manager.beginFrame()
    drawScene()
    crt_manager.endFrame()
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
-- more (see ultimate_ui/sandbox/README.md). Without the flag this does nothing. Safe
-- to leave out of release builds: delete ultimate_ui/sandbox/ (this block then skips itself).
-- ==========================================
if UI.hasSandbox() and UI.sandbox.requested(arg) then
    UI.sandbox.attach()
end
