-- ui/hud.lua
-- Persistent in-game HUD elements: the version watermark, an FPS counter,
-- a generic stats side panel, and the floating game title. All of them are
-- plain draw functions you call from your own love.draw(); none of them
-- know anything about your gameplay -- you hand them the data.
local ui_state = require("ui_state")
local config = require("config")
local helpers = require("ui.helpers")
local getFont = helpers.getFont

local hud = {}

-- 1. Version watermark (bottom-right). Text comes from config.version.
function hud.drawVersionText(screenWidth, screenHeight, uiScale)
    local padding = 20 * uiScale
    local y = screenHeight - (18 * uiScale) - padding

    love.graphics.setFont(getFont(18 * uiScale))
    love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
    love.graphics.printf(config.version, 0, y, screenWidth - padding, "right")
    love.graphics.setColor(1, 1, 1, 1)
end

-- 2. FPS counter (top-left). Only draws when config.showFPS is true, which
-- Settings -> Other -> SHOW FPS toggles.
function hud.drawFPS(uiScale)
    if not config.showFPS then return end
    love.graphics.setFont(getFont(18 * uiScale))
    love.graphics.setColor(0.4, 1, 0.5, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 12 * uiScale, 10 * uiScale)
    love.graphics.setColor(1, 1, 1, 1)
end

-- 3. Side panel. `stats` is a list of { label, value } pairs, drawn top to
-- bottom at (x, y) in the rainbow pulse color. Example:
--   hud.drawSidePanel({ {"SCORE", 120}, {"LEVEL", 3} }, 40, 120, uiScale)
function hud.drawSidePanel(stats, x, y, uiScale)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    love.graphics.setColor(r/255, g/255, b/255)
    love.graphics.setFont(getFont(30 * uiScale))
    for i, stat in ipairs(stats) do
        love.graphics.print(stat[1] .. ":  " .. tostring(stat[2]), x, y + (i - 1) * 40 * uiScale)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- 4. Game title (top-center), from config.title.
function hud.drawGameTitle(screenWidth, uiScale)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    love.graphics.setColor(r/255, g/255, b/255)
    love.graphics.setFont(getFont(60 * uiScale))
    local textWidth = love.graphics.getFont():getWidth(config.title)
    love.graphics.print(config.title, (screenWidth / 2) - (textWidth / 2), 50 * uiScale)
    love.graphics.setColor(1, 1, 1, 1)
end

return hud
