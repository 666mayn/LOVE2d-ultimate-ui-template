-- ui/loading_screen.lua
-- Loading screen with a rainbow progress bar.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui_state = require(ROOT .. ".ui_state")
local helpers = require(ROOT .. ".ui.helpers")
local widgets = require(ROOT .. ".ui.widgets")
local getFont = helpers.getFont

local loading_screen = {}

-- The page's text as data, so the sandbox editor (F11) can edit it. (The sandbox holds the
-- loading screen open while edit mode is on, so you have time to click the title.)
local DEFAULT_LABEL = "LOADING..."
local page = widgets.textPage{
    id = "loadingScreen", file = "ui/loading_screen.lua",
    labels = { { id = "title", text = DEFAULT_LABEL, fontSize = 48, color = "rainbow" } },
}

-- Draws the loading screen. timeLeft/maxTime drive the progress bar.
function loading_screen.drawLoadingScreen(screenWidth, screenHeight, uiScale, timeLeft, maxTime, label)
    -- Shared menu background if there is one (solid black otherwise), so the
    -- picture carries straight through PLAY -> loading -> game.
    helpers.drawMenuBackdrop(screenWidth, screenHeight, 1)

    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)

    -- Title Text. The page's own text wins once it has been changed (editor or
    -- ui/page_texts.lua); until then the `label` the caller passed in is shown.
    local title = page.label("title")
    local text = widgets.resolveText(title.text)
    if title.text == DEFAULT_LABEL and label then text = label end
    local tr, tg, tb = page.rgb(title, r, g, b)
    local titleY = screenHeight/2 - 120 * uiScale
    love.graphics.setColor(tr/255, tg/255, tb/255)
    love.graphics.setFont(getFont(48 * uiScale))
    love.graphics.printf(text, 0, titleY, screenWidth, "center")
    page.report({
        { kind = "label", id = "title", text = text, fontSize = 48, color = title.color,
          x = 0, y = titleY, w = screenWidth, h = 48 * uiScale },
    }, screenWidth, screenHeight, uiScale)

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
