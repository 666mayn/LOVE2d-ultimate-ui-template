-- ui/loading_screen.lua
-- Loading screen with a rainbow progress bar.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui_state = require(ROOT .. ".ui_state")
local helpers = require(ROOT .. ".ui.helpers")
local getFont = helpers.getFont

local loading_screen = {}

-- Draws the loading screen. timeLeft/maxTime drive the progress bar.
function loading_screen.drawLoadingScreen(screenWidth, screenHeight, uiScale, timeLeft, maxTime, label)
    -- Shared menu background if there is one (solid black otherwise), so the
    -- picture carries straight through PLAY -> loading -> game.
    helpers.drawMenuBackdrop(screenWidth, screenHeight, 1)

    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    love.graphics.setColor(r/255, g/255, b/255)

    -- Title Text
    love.graphics.setFont(getFont(48 * uiScale))
    love.graphics.printf(label or "LOADING...", 0, screenHeight/2 - 120 * uiScale, screenWidth, "center")

    -- Progress Bar
    maxTime = maxTime or 2.0
    local progress = 1 - (timeLeft / maxTime)
    local barWidth = 400 * uiScale
    local barHeight = 24 * uiScale
    local barX = (screenWidth - barWidth) / 2
    local barY = screenHeight/2 - 20 * uiScale

    -- Background track
    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

    -- Fill track
    love.graphics.setColor(r/255, g/255, b/255)
    love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)

    -- Border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
end

return loading_screen
