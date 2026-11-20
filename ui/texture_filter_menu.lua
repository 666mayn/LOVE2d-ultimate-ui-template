-- ui/texture_filter_menu.lua
-- The "TEXTURE FILTER" screen one level below Settings (Settings -> Texture
-- Filter), sibling of ui/other_settings_menu.lua. One row per mode
-- registered in texture_filter_manager.lua (Sharp / Smooth / Hybrid), plus
-- BACK. Clicking a row switches the live filter immediately and persists it.
--
-- Adding a mode later = one line in texture_filter_manager.lua's `defs`;
-- this file's rows are built from that list.
local ui_state = require("ui_state")
local helpers = require("ui.helpers")
local getFont = helpers.getFont
local texture_filter_manager = require("texture_filter_manager")

local texture_filter_menu = {}

local function buildRows()
    local rows = {}
    for i, def in ipairs(texture_filter_manager.getOptions()) do
        table.insert(rows, { type = "filter", index = i, label = string.upper(def.name) })
    end
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

-- Same box chrome as other_settings_menu's label+value row.
local function drawRow(label, valueText, valueColor, centerX, y, rowWidth, rowHeight, isSelected, isHovered, uiScale, r, g, b, alpha)
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
    love.graphics.printf(label, centerX - rowWidth / 2 + pad, y + (rowHeight - 24 * uiScale) / 2, rowWidth * 0.7, "left")

    if valueText ~= "" then
        love.graphics.setColor(valueColor[1], valueColor[2], valueColor[3], alpha)
        love.graphics.printf(valueText, centerX - rowWidth / 2, y + (rowHeight - 24 * uiScale) / 2, rowWidth - pad, "right")
    end
end

function texture_filter_menu.drawTextureFilterMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("textureFilterMenu")

    love.graphics.setColor(0, 0, 0, 180/255)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    local centerX = math.floor(screenWidth / 2)

    local rows, rowHeight, rowWidth, rowSpacing, startY = layout(screenHeight, uiScale)

    local titleY = startY - 90 * uiScale
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(centerX, titleY + (52 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(r/255, g/255, b/255, titleAlpha)
        love.graphics.setFont(getFont(52 * uiScale))
        love.graphics.printf("T E X T U R E  F I L T E R", 0, titleY, screenWidth, "center")
    end)

    local activeIndex = texture_filter_manager.getActiveIndex()
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
            if row.type == "filter" then
                local valueText, color = "", { 0.85, 0.85, 0.85 }
                if row.index == activeIndex then
                    valueText, color = "ACTIVE", { 0.4, 1, 0.5 }
                end
                drawRow(row.label, valueText, color, centerX, y, rowWidth, rowHeight,
                    isSelected, hovered, uiScale, r, g, b, alpha)
            else
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
        love.graphics.printf("Click a mode to switch how textures are sampled -- [Esc] or [B] to go back",
            0, hintY, screenWidth, "center")
    end)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Returns:
--   { action = "select", row = <row index> }  -- pass the row to activateRow()
--   { action = "back" }
--   nil
function texture_filter_menu.handleTextureFilterMenuClick(x, y, screenWidth, screenHeight, uiScale)
    local rows, rowHeight, rowWidth, rowSpacing, startY = layout(screenHeight, uiScale)
    local centerX = math.floor(screenWidth / 2)
    for i, row in ipairs(rows) do
        local ry = rowY(startY, rowHeight, rowSpacing, i)
        if x >= centerX - rowWidth / 2 and x <= centerX + rowWidth / 2 and y >= ry and y <= ry + rowHeight then
            if row.type == "action" and row.id == "back" then
                return { action = "back" }
            end
            return { action = "select", row = i }
        end
    end
    return nil
end

function texture_filter_menu.getRowCount()
    return #buildRows()
end

function texture_filter_menu.getRowAt(index)
    return buildRows()[index]
end

-- Shared "do what this row says" used by mouse / keyboard / gamepad so the
-- input code doesn't reimplement it. Returns "back" if the menu should
-- close, otherwise nil.
function texture_filter_menu.activateRow(row)
    if not row then return nil end
    if row.type == "filter" then
        texture_filter_manager.select(row.index)
        return nil
    end
    return "back"
end

return texture_filter_menu
