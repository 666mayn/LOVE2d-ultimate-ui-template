-- ui/pause_menu.lua
-- Pause menu screen: draw + click handling.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui_state = require(ROOT .. ".ui_state")
local helpers = require(ROOT .. ".ui.helpers")
local getFont = helpers.getFont

local pause_menu = {}

-- Row order == pauseSelection index. Add a button = add a line here and
-- handle its action in menu_input.lua.
local BUTTONS = {
    { label = "RESUME",       action = "resume" },
    { label = "SETTINGS",     action = "settings" },
    { label = "EXIT TO MENU", action = "exit_to_menu" },
}

local function layout(screenWidth, screenHeight, uiScale)
    local buttonWidth = 260 * uiScale
    local buttonHeight = 50 * uiScale
    local buttonSpacing = 20 * uiScale
    local centerX = screenWidth / 2
    local n = #BUTTONS
    local totalHeight = n * buttonHeight + (n - 1) * buttonSpacing
    local startY = screenHeight / 2 - totalHeight / 2
    return buttonWidth, buttonHeight, buttonSpacing, centerX, startY
end

function pause_menu.drawPauseMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("pauseMenu")

    helpers.drawMenuBackdrop(screenWidth, screenHeight, 180/255)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)

    local buttonWidth, buttonHeight, buttonSpacing, centerX, startY = layout(screenWidth, screenHeight, uiScale)

    local titleY = startY - 100 * uiScale
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(screenWidth / 2, titleY + (60 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(r/255, g/255, b/255, titleAlpha)
        love.graphics.setFont(getFont(60 * uiScale))
        love.graphics.printf("PAUSED", 0, titleY, screenWidth, "center")
    end)

    local ys, hovered = {}, {}
    local anyHovered = false
    for i = 1, #BUTTONS do
        ys[i] = startY + (i - 1) * (buttonHeight + buttonSpacing)
        hovered[i] = mouseX and mouseY and (mouseX >= centerX - buttonWidth / 2 and mouseX <= centerX + buttonWidth / 2 and mouseY >= ys[i] and mouseY <= ys[i] + buttonHeight)
        if hovered[i] then anyHovered = true end
    end

    local baseDelay = 0.18
    local stagger = 0.08
    for i, btn in ipairs(BUTTONS) do
        local scale, alpha = helpers.popIn(t, baseDelay + (i - 1) * stagger, 0.4)
        local y = ys[i]
        helpers.withPop(centerX, y + buttonHeight / 2, scale, alpha, function()
            local highlight = hovered[i] or (selection == i and not anyHovered)
            if highlight then
                love.graphics.setColor(80/255, 80/255, 80/255, alpha)
                love.graphics.rectangle("fill", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.rectangle("line", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
            else
                love.graphics.setColor(50/255, 50/255, 50/255, alpha)
                love.graphics.rectangle("fill", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
                love.graphics.setColor(100/255, 100/255, 100/255, alpha)
                love.graphics.rectangle("line", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
            end
            love.graphics.setColor(r/255, g/255, b/255, alpha)
            love.graphics.setFont(getFont(24 * uiScale))
            love.graphics.printf(btn.label, centerX - buttonWidth / 2, y + (buttonHeight - (24 * uiScale)) / 2, buttonWidth, "center")
        end)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function pause_menu.handlePauseMenuClick(x, y, screenWidth, screenHeight, uiScale)
    local buttonWidth, buttonHeight, buttonSpacing, centerX, startY = layout(screenWidth, screenHeight, uiScale)
    for i, btn in ipairs(BUTTONS) do
        local by = startY + (i - 1) * (buttonHeight + buttonSpacing)
        if x >= centerX - buttonWidth / 2 and x <= centerX + buttonWidth / 2 and y >= by and y <= by + buttonHeight then
            return btn.action
        end
    end
    return nil
end

function pause_menu.getRowCount() return #BUTTONS end
function pause_menu.getActionAt(index) return BUTTONS[index] and BUTTONS[index].action or nil end

return pause_menu
