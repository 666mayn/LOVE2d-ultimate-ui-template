-- ui/settings_menu.lua
-- Settings category screen: the deeper menu that opens when the main (or
-- pause) menu's SETTINGS button is clicked. Lists categories as
-- buttons; each category owns its own deeper screen (e.g. "KEYBOARD" ->
-- ui/keyboard_menu.lua, "CONTROLLER" -> ui/controller_menu.lua,
-- "OTHER" -> ui/other_settings_menu.lua, "TEXTURE FILTER" ->
-- ui/texture_filter_menu.lua). Adding a new category later is one more
-- entry in CATEGORIES plus its own screen file -- this file's layout code
-- doesn't need to change since it's already parametric on button count,
-- same as main_menu.lua.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui_state = require(ROOT .. ".ui_state")
local helpers = require(ROOT .. ".ui.helpers")
local widgets = require(ROOT .. ".ui.widgets")
local getFont = helpers.getFont

-- The page's texts as data, so the sandbox editor (F11) can edit them. Each category is
-- looked up by its `action` (a stable key), so a saved edit follows its button.
local page = widgets.textPage{
    id = "settingsMenu", file = "ui/settings_menu.lua",
    labels = { { id = "title", text = "S E T T I N G S", fontSize = 60, color = "rainbow" } },
}

local settings_menu = {}

-- action: what handleSettingsMenuClick()/gamepad nav returns when this
-- button is chosen. "back" is always last.
local CATEGORIES = {
    { label = "K E Y B O A R D",       action = "keyboard" },
    { label = "C O N T R O L L E R", action = "controller" },
    { label = "O T H E R",       action = "other_settings" },
    { label = "T E X T U R E S", action = "texture_filter" },
    { label = "B A C K",                   action = "back" },
}
-- The editable entry behind a category (its text / color), created on first use.
local function entryOf(category) return page.item(category.action, category.label) end

local function layout(screenWidth, screenHeight, uiScale)
    local buttonWidth = math.floor(400 * uiScale)
    local buttonHeight = math.floor(60 * uiScale)
    local buttonSpacing = math.floor(20 * uiScale)
    local centerX = math.floor(screenWidth / 2)
    -- Extra breathing room before the last button (BACK), matching the
    -- gap before EXIT on the main menu. Change 15 to taste.
    local extraGap = math.floor(15 * uiScale)
    local count = #CATEGORIES
    local totalHeight = count * buttonHeight + (count - 1) * buttonSpacing + extraGap
    local startY = math.floor(screenHeight / 2 - totalHeight / 2)
    return buttonWidth, buttonHeight, buttonSpacing, centerX, startY, extraGap
end

local function buttonY(startY, buttonHeight, buttonSpacing, index, extraGap)
    local y = startY + (index - 1) * (buttonHeight + buttonSpacing)
    if index == #CATEGORIES then y = y + extraGap end
    return y
end

function settings_menu.drawSettingsMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("settingsMenu")

    helpers.drawMenuBackdrop(screenWidth, screenHeight, 180/255)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    local buttonWidth, buttonHeight, buttonSpacing, centerX, startY, extraGap = layout(screenWidth, screenHeight, uiScale)

    -- Title sits a fixed distance above the first button, so the gap stays
    -- consistent no matter how many categories are added. Change the 110
    -- below to move 'SETTINGS' up/down.
    local titleY = startY - 110 * uiScale
    local title = page.label("title")
    local titleText = widgets.resolveText(title.text)
    local tr, tg, tb = page.rgb(title, r, g, b)
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(screenWidth / 2, titleY + (60 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(tr/255, tg/255, tb/255, titleAlpha)
        love.graphics.setFont(getFont(60 * uiScale, "title", title.font))
        love.graphics.printf(titleText, 0, titleY, screenWidth, "center")
    end)

    local reported = {
        { kind = "label", id = "title", text = titleText, fontSize = 60, color = title.color,
          x = 0, y = titleY, w = screenWidth, h = 60 * uiScale },
    }

    local hovers = {}
    local anyHovered = false
    for i in ipairs(CATEGORIES) do
        local y = buttonY(startY, buttonHeight, buttonSpacing, i, extraGap)
        local hovered = mouseX and mouseY
            and mouseX >= centerX - buttonWidth/2 and mouseX <= centerX + buttonWidth/2
            and mouseY >= y and mouseY <= y + buttonHeight
        hovers[i] = hovered
        anyHovered = anyHovered or hovered
    end

    local baseDelay = 0.18
    local stagger = 0.08
    for i, category in ipairs(CATEGORIES) do
        local y = buttonY(startY, buttonHeight, buttonSpacing, i, extraGap)
        local entry = entryOf(category)
        local text = widgets.resolveText(entry.text)
        local br, bg, bb = page.rgb(entry, r, g, b)
        helpers.drawPoppedButton(text, centerX, y, buttonWidth, buttonHeight,
            selection == i, hovers[i], anyHovered, uiScale, br, bg, bb, t, baseDelay + (i - 1) * stagger, entry.font)
        reported[#reported + 1] = { kind = "button", id = "rows", key = category.action, index = i,
            text = text, color = entry.color, x = centerX - buttonWidth / 2, y = y, w = buttonWidth, h = buttonHeight }
    end
    love.graphics.setColor(1, 1, 1, 1)
    page.report(reported, screenWidth, screenHeight, uiScale)
end

-- Returns the category's `action` string ("keyboard", "back", ...) or nil.
function settings_menu.handleSettingsMenuClick(x, y, screenWidth, screenHeight, uiScale)
    local buttonWidth, buttonHeight, buttonSpacing, centerX, startY, extraGap = layout(screenWidth, screenHeight, uiScale)
    for i, category in ipairs(CATEGORIES) do
        local buttonYPos = buttonY(startY, buttonHeight, buttonSpacing, i, extraGap)
        if x >= centerX - buttonWidth/2 and x <= centerX + buttonWidth/2
            and y >= buttonYPos and y <= buttonYPos + buttonHeight then
            return category.action
        end
    end
    return nil
end

function settings_menu.getRowCount()
    return #CATEGORIES
end

function settings_menu.getActionAt(index)
    local category = CATEGORIES[index]
    return category and category.action or nil
end

return settings_menu
