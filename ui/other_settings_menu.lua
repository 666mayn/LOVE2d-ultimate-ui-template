-- ui/other_settings_menu.lua
-- The "OTHER SETTINGS" screen one level below Settings (Settings -> Other
-- Settings), sibling of ui/keyboard_menu.lua and ui/controller_menu.lua.
-- Rows here click-to-cycle through a fixed set of options (e.g. slow/
-- normal/fast) instead of starting a rebind capture -- see
-- other_settings.lua for the row list and cycling logic. More config- and
-- sound-related rows get added to ROW_DEFS over there, not here.
local ui_state = require("ui_state")
local helpers = require("ui.helpers")
local getFont = helpers.getFont
local other_settings = require("other_settings")

local other_settings_menu = {}

local function buildRows()
    local rows = {}
    for _, def in ipairs(other_settings.rowOrder) do
        table.insert(rows, { type = "cycle", id = def.id, label = def.label })
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

-- Shared renderer for label+value rows. Left-aligned label, right-aligned
-- value, same box chrome as helpers.drawScaledButton so it matches every
-- other menu without duplicating that code.
local function drawRow(label, valueText, centerX, y, rowWidth, rowHeight, isSelected, isHovered, uiScale, r, g, b, alpha)
    local highlight = isHovered or isSelected
    if highlight then
        love.graphics.setColor(80/255, 80/255, 80/255, alpha)
    else
        love.graphics.setColor(50/255, 50/255, 50/255, alpha)
    end
    love.graphics.rectangle("fill", centerX - rowWidth / 2, y, rowWidth, rowHeight)
    love.graphics.setColor(highlight and 1 or 100/255, highlight and 1 or 100/255, highlight and 1 or 100/255, alpha)
    love.graphics.rectangle("line", centerX - rowWidth / 2, y, rowWidth, rowHeight)

    local pad = 24 * uiScale
    love.graphics.setColor(r/255, g/255, b/255, alpha)
    love.graphics.setFont(getFont(24 * uiScale))
    love.graphics.printf(label, centerX - rowWidth / 2 + pad, y + (rowHeight - 24 * uiScale) / 2, rowWidth * 0.55, "left")

    love.graphics.setColor(0.85, 0.85, 0.85, alpha)
    love.graphics.printf(valueText, centerX - rowWidth / 2, y + (rowHeight - 24 * uiScale) / 2, rowWidth - pad, "right")
end

function other_settings_menu.drawOtherSettingsMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("otherSettingsMenu")

    love.graphics.setColor(0, 0, 0, 180/255)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    local centerX = math.floor(screenWidth / 2)

    local rows, rowHeight, rowWidth, rowSpacing, startY = layout(screenHeight, uiScale)

    -- Positioned relative to startY (like ui/controller_menu.lua) rather
    -- than a fixed offset, so this stays correct as more rows get added
    -- to other_settings.lua's ROW_DEFS later instead of clipping.
    local titleGap = 90 * uiScale
    local titleY = startY - titleGap
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(centerX, titleY + (52 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(r/255, g/255, b/255, titleAlpha)
        love.graphics.setFont(getFont(52 * uiScale))
        love.graphics.printf("O T H E R  S E T T I N G S", 0, titleY, screenWidth, "center")
    end)

    local baseDelay = 0.15
    local stagger = 0.04
    for i, row in ipairs(rows) do
        local y = rowY(startY, rowHeight, rowSpacing, i)
        local hovered = mouseX and mouseY
            and mouseX >= centerX - rowWidth / 2 and mouseX <= centerX + rowWidth / 2
            and mouseY >= y and mouseY <= y + rowHeight
        local scale, alpha = helpers.popIn(t, baseDelay + (i - 1) * stagger, 0.35)

        helpers.withPop(centerX, y + rowHeight / 2, scale, alpha, function()
            local isSelected = (selection == i)

            if row.type == "cycle" then
                local valueText = other_settings.getCurrentLabel(row.id)
                drawRow(row.label, valueText, centerX, y, rowWidth, rowHeight,
                    isSelected, hovered, uiScale, r, g, b, alpha)

            elseif row.type == "action" then
                helpers.drawScaledButton(row.label, centerX, y, rowWidth, rowHeight,
                    isSelected, hovered, false, uiScale, r, g, b, alpha)
            end
        end)
    end

    local hintScale, hintAlpha = helpers.popIn(t, baseDelay + #rows * stagger + 0.1, 0.35)
    local hintY = rowY(startY, rowHeight, rowSpacing, #rows + 1)
    helpers.withPop(centerX, hintY, hintScale, hintAlpha, function()
        love.graphics.setColor(0.6, 0.6, 0.6, hintAlpha)
        love.graphics.setFont(getFont(18 * uiScale))
        love.graphics.printf("Click a setting to cycle its value -- [Esc] or [B] to go back",
            0, hintY, screenWidth, "center")
    end)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Returns:
--   { action = "cycle", id = "<row id>" }
--   { action = "reset" }
--   { action = "back" }   -- one level up, back to the Settings category list
--   nil
function other_settings_menu.handleOtherSettingsMenuClick(x, y, screenWidth, screenHeight, uiScale)
    local rows, rowHeight, rowWidth, rowSpacing, startY = layout(screenHeight, uiScale)
    local centerX = math.floor(screenWidth / 2)

    for i, row in ipairs(rows) do
        local ry = rowY(startY, rowHeight, rowSpacing, i)
        if x >= centerX - rowWidth / 2 and x <= centerX + rowWidth / 2 and y >= ry and y <= ry + rowHeight then
            if row.type == "cycle" then
                return { action = "cycle", id = row.id }
            elseif row.id == "reset" then
                return { action = "reset" }
            elseif row.id == "back" then
                return { action = "back" }
            end
        end
    end
    return nil
end

function other_settings_menu.getRowCount()
    return #buildRows()
end

-- Lets input_gamepad.lua resolve an 'a' press on the currently-selected
-- row without duplicating the row list / ordering logic.
function other_settings_menu.getRowAt(index)
    local rows = buildRows()
    return rows[index]
end

return other_settings_menu
