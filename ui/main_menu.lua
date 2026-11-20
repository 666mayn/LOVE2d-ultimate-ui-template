-- ui/main_menu.lua
-- Main menu screen: draw + click handling.
local ui_state = require("ui_state")
local config = require("config")
local helpers = require("ui.helpers")
local getFont = helpers.getFont

local main_menu = {}

-- Row order == menuSelection index (menu_input.lua relies on this).
-- To add a button: add a label + matching action here, then handle the new
-- action string in menu_input.lua's main-menu handler. Layout is
-- parametric on the number of rows, so nothing else needs to change.
local LABELS  = { "P L A Y", "S E T T I N G S", "E X I T" }
local ACTIONS = { "play",    "settings",        "exit" }

-- Wrap dimensions in math.floor() to snap to the pixel grid. Shared by
-- draw + click handling. The last button (EXIT) gets an extra gap above it.
function main_menu._layout(screenWidth, screenHeight, uiScale)
    local buttonWidth = math.floor(400 * uiScale)
    local buttonHeight = math.floor(60 * uiScale)
    local buttonSpacing = math.floor(20 * uiScale)
    local extraGap = math.floor(15 * uiScale)
    local centerX = math.floor(screenWidth / 2)

    local n = #LABELS
    local totalHeight = n * buttonHeight + (n - 1) * buttonSpacing + extraGap
    local startY = math.floor(screenHeight/2 - totalHeight / 2)

    local ys = {}
    for i = 1, n do
        ys[i] = startY + (i - 1) * (buttonHeight + buttonSpacing)
    end
    ys[n] = ys[n] + extraGap
    return ys, buttonWidth, buttonHeight, centerX, startY
end

function main_menu.drawMainMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("mainMenu")

    love.graphics.setColor(0, 0, 0, 180/255)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)

    local ys, buttonWidth, buttonHeight, centerX, startY = main_menu._layout(screenWidth, screenHeight, uiScale)

    -- Title sits a fixed distance above the first button (so it follows the
    -- button block no matter how many rows you add) and pops in first, with
    -- a little overshoot/bounce.
    local titleY = startY - 150 * uiScale
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(screenWidth / 2, titleY + (72 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(r/255, g/255, b/255, titleAlpha)
        love.graphics.setFont(getFont(72 * uiScale))
        love.graphics.printf(config.title, 0, titleY, screenWidth, "center")
    end)

    -- Optional subtitle (config.subtitle = "" turns it off)
    if config.subtitle and config.subtitle ~= "" then
        local subScale, subAlpha = helpers.popIn(t, 0.1, 0.5)
        local subY = titleY + 84 * uiScale
        helpers.withPop(screenWidth / 2, subY + (34 * uiScale) / 2, subScale, subAlpha, function()
            love.graphics.setColor(1, 0.76, 0.12, subAlpha)
            love.graphics.setFont(getFont(34 * uiScale))
            love.graphics.printf(config.subtitle, 0, subY, screenWidth, "center")
        end)
    end

    local hovered = {}
    local anyHovered = false
    for i = 1, #LABELS do
        local h = mouseX and mouseY and (mouseX >= centerX - buttonWidth/2 and mouseX <= centerX + buttonWidth/2 and mouseY >= ys[i] and mouseY <= ys[i] + buttonHeight)
        hovered[i] = h
        if h then anyHovered = true end
    end

    -- Buttons cascade in one after another after the title
    local baseDelay = 0.18
    local stagger = 0.08
    for i = 1, #LABELS do
        helpers.drawPoppedButton(LABELS[i], centerX, ys[i], buttonWidth, buttonHeight, selection == i, hovered[i], anyHovered, uiScale, r, g, b, t, baseDelay + (i - 1) * stagger)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function main_menu.handleMainMenuClick(x, y, screenWidth, screenHeight, uiScale)
    -- Uses the same layout function as the draw call, so hit boxes can
    -- never drift from what's on screen.
    local ys, buttonWidth, buttonHeight, centerX = main_menu._layout(screenWidth, screenHeight, uiScale)
    for i = 1, #ACTIONS do
        if x >= centerX - buttonWidth/2 and x <= centerX + buttonWidth/2 and y >= ys[i] and y <= ys[i] + buttonHeight then
            return ACTIONS[i]
        end
    end
    return nil
end

function main_menu.getRowCount() return #ACTIONS end
function main_menu.getActionAt(index) return ACTIONS[index] end

return main_menu
