-- ui/keyboard_menu.lua
-- The "KEYBOARD" screen one level below Settings (Settings -> Keyboard),
-- same relationship as MainMenu -> Settings. Lists each rebindable
-- keyboard action as a row; clicking one starts a capture (see keybinds.lua).
-- Sibling of ui/controller_menu.lua, which is the same shape but for
-- gamepad binds (see controller.lua).
--
-- Row-type engine kept generic (keybind/slider/action) even though only
-- keybind+action rows are used today, so a future category screen (e.g.
-- an AUDIO screen for the volume sliders) can copy this file's shape
-- instead of reinventing row rendering.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui_state = require(ROOT .. ".ui_state")
local helpers = require(ROOT .. ".ui.helpers")
local widgets = require(ROOT .. ".ui.widgets")
local getFont = helpers.getFont
local rowFont            -- per-row font override for the row being drawn (entry.font), see fonts.lua
local rowRadius          -- per-row corner radius for the row being drawn (entry.radius), see helpers.cornerRadius

-- The page's texts as data, so the sandbox editor (F11) can edit them. Row labels are
-- keyed by the row id (an action name), so a saved edit follows its row.
local page = widgets.textPage{
    id = "keyboardMenu", file = "ui/keyboard_menu.lua",
    labels = {
        { id = "title", text = "K E Y B O A R D", fontSize = 52, color = "rainbow" },
        { id = "hint",  text = "Click a bind then press a key to rebind it -- [Esc] or [B] to go back", fontSize = 18, color = { 0.6, 0.6, 0.6 } },
    },
}
local keybinds = require(ROOT .. ".keybinds")

local keyboard_menu = {}

local function buildRows()
    local rows = {}
    for _, def in ipairs(keybinds.actionOrder) do
        table.insert(rows, { type = "keybind", id = def.id, label = def.label })
    end
    table.insert(rows, { type = "action", id = "reset", label = "RESET TO DEFAULTS" })
    table.insert(rows, { type = "action", id = "back", label = "BACK" })
    return rows
end

local function layout(screenHeight, uiScale)
    local rowHeight = math.floor(64 * uiScale)
    local rowWidth = math.floor(560 * uiScale)
    local rowSpacing = math.floor(10 * uiScale)
    local rows = buildRows()
    local totalHeight = #rows * rowHeight + (#rows - 1) * rowSpacing
    local startY = math.floor(screenHeight / 2 - totalHeight / 2)
    return rows, rowHeight, rowWidth, rowSpacing, startY
end

local function rowY(startY, rowHeight, rowSpacing, index)
    return startY + (index - 1) * (rowHeight + rowSpacing)
end

-- Shared renderer for label+value rows (keybind/slider). Left-aligned
-- label, right-aligned value, same box chrome as helpers.drawScaledButton
-- so it matches every other menu without duplicating that code.
local function drawRow(label, valueText, centerX, y, rowWidth, rowHeight, isSelected, isHovered, uiScale, r, g, b, alpha, isCapturing)
    local highlight = isHovered or (isSelected and not isCapturing)
    if isCapturing then
        love.graphics.setColor(90/255, 60/255, 20/255, alpha)
    elseif highlight then
        love.graphics.setColor(80/255, 80/255, 80/255, alpha)
    else
        love.graphics.setColor(50/255, 50/255, 50/255, alpha)
    end
    helpers.rect("fill", centerX - rowWidth / 2, y, rowWidth, rowHeight, helpers.cornerRadius(rowRadius, uiScale, rowWidth, rowHeight))
    love.graphics.setColor(highlight and 1 or 100/255, highlight and 1 or 100/255, highlight and 1 or 100/255, alpha)
    helpers.rect("line", centerX - rowWidth / 2, y, rowWidth, rowHeight, helpers.cornerRadius(rowRadius, uiScale, rowWidth, rowHeight))

    local pad = 24 * uiScale
    love.graphics.setColor(r/255, g/255, b/255, alpha)
    love.graphics.setFont(getFont(24 * uiScale, "row", rowFont))
    love.graphics.printf(label, centerX - rowWidth / 2 + pad, helpers.textY(y, rowHeight), rowWidth * 0.55, "left")

    love.graphics.setColor(isCapturing and 1 or 0.85, isCapturing and 0.85 or 0.85, isCapturing and 0.3 or 0.85, alpha)
    love.graphics.printf(valueText, centerX - rowWidth / 2, helpers.textY(y, rowHeight), rowWidth - pad, "right")
end

function keyboard_menu.drawKeyboardMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("keyboardMenu")

    helpers.drawMenuBackdrop(screenWidth, screenHeight, 180/255)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    local centerX = math.floor(screenWidth / 2)

    local rows, rowHeight, rowWidth, rowSpacing, startY = layout(screenHeight, uiScale)

    -- Positioned relative to startY (like the other settings screens)
    -- rather than a fixed offset, so the title stays clear of the rows
    -- as more keybind actions get added.
    local title = page.label("title")
    local titleY = startY - 90 * uiScale + page.dy(title, uiScale)
    local titleText = widgets.resolveText(title.text)
    local tr, tg, tb = page.rgb(title, r, g, b)
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(centerX, titleY + (52 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(tr/255, tg/255, tb/255, titleAlpha)
        love.graphics.setFont(getFont(52 * uiScale, "title", title.font))
        love.graphics.printf(titleText, 0, titleY, screenWidth, "center")
    end)
    -- What was drawn, for the sandbox editor (see widgets.textPage).
    local reported = {
        { kind = "label", id = "title", text = titleText, fontSize = 52, color = title.color,
          x = 0, y = titleY, w = screenWidth, h = 52 * uiScale },
    }
    local capturingAction = keybinds.getCapturingAction()

    local baseDelay = 0.15
    local stagger = 0.04
    for i, row in ipairs(rows) do
        local y = rowY(startY, rowHeight, rowSpacing, i) + page.rowDy(row.id, uiScale)
        local hovered = mouseX and mouseY
            and mouseX >= centerX - rowWidth / 2 and mouseX <= centerX + rowWidth / 2
            and mouseY >= y and mouseY <= y + rowHeight
        local scale, alpha = helpers.popIn(t, baseDelay + (i - 1) * stagger, 0.35)
        local entry = page.item(row.id, row.label)
        rowFont = entry.font
        rowRadius = entry.radius
        local rowText = widgets.resolveText(entry.text)
        local rr, rg, rb = page.rgb(entry, r, g, b)
        reported[#reported + 1] = { kind = "button", id = "rows", key = row.id, index = i, text = rowText,
            color = entry.color, x = centerX - rowWidth / 2, y = y, w = rowWidth, h = rowHeight }

        helpers.withPop(centerX, y + rowHeight / 2, scale, alpha, function()
            local isSelected = (selection == i)

            if row.type == "keybind" then
                local isCapturingThis = (capturingAction == row.id)
                local valueText = isCapturingThis and "PRESS A KEY..." or keybinds.getDisplayName(row.id)
                drawRow(rowText, valueText, centerX, y, rowWidth, rowHeight,
                    isSelected, hovered, uiScale, rr, rg, rb, alpha, isCapturingThis)

            elseif row.type == "action" then
                helpers.drawScaledButton(rowText, centerX, y, rowWidth, rowHeight,
                    isSelected, hovered, false, uiScale, rr, rg, rb, alpha, entry.font, entry.radius)
            end
        end)
    end

    local hintScale, hintAlpha = helpers.popIn(t, baseDelay + #rows * stagger + 0.1, 0.35)
    local hint = page.label("hint")
    local hintY = rowY(startY, rowHeight, rowSpacing, #rows + 1) + page.dy(hint, uiScale)
    local hintText = widgets.resolveText(hint.text)
    local hr, hg, hb = page.rgb(hint, 153, 153, 153)
    helpers.withPop(centerX, hintY, hintScale, hintAlpha, function()
        love.graphics.setColor(hr/255, hg/255, hb/255, hintAlpha)
        love.graphics.setFont(getFont(18 * uiScale, "hint", hint.font))
        love.graphics.printf(hintText, 0, hintY, screenWidth, "center")
    end)
    reported[#reported + 1] = { kind = "label", id = "hint", text = hintText, fontSize = 18, color = hint.color,
        x = 0, y = hintY, w = screenWidth, h = 18 * uiScale }

    love.graphics.setColor(1, 1, 1, 1)
    page.report(reported, screenWidth, screenHeight, uiScale)
end

-- Returns:
--   { action = "rebind", id = "<row id>" }
--   { action = "reset" }
--   { action = "back" }   -- one level up, back to the Settings category list
--   nil
function keyboard_menu.handleKeyboardMenuClick(x, y, screenWidth, screenHeight, uiScale)
    local rows, rowHeight, rowWidth, rowSpacing, startY = layout(screenHeight, uiScale)
    local centerX = math.floor(screenWidth / 2)

    for i, row in ipairs(rows) do
        local ry = rowY(startY, rowHeight, rowSpacing, i) + page.rowDy(row.id, uiScale)
        if x >= centerX - rowWidth / 2 and x <= centerX + rowWidth / 2 and y >= ry and y <= ry + rowHeight then
            if row.type == "keybind" then
                return { action = "rebind", id = row.id }
            elseif row.id == "reset" then
                return { action = "reset" }
            elseif row.id == "back" then
                return { action = "back" }
            end
        end
    end
    return nil
end

function keyboard_menu.getRowCount()
    return #buildRows()
end

-- Lets input_gamepad.lua resolve an 'a' press on the currently-selected
-- row without duplicating the row list / ordering logic.
function keyboard_menu.getRowAt(index)
    local rows = buildRows()
    return rows[index]
end

return keyboard_menu
