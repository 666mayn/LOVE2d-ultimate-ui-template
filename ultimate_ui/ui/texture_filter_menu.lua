-- ui/texture_filter_menu.lua
-- The "TEXTURES" screen one level below Settings (Settings -> Textures),
-- sibling of ui/other_settings_menu.lua. Two sections:
--
--   1. Texture sampling: one row per mode in texture_filter_manager.lua
--      (Sharp / Smooth / Hybrid). Click a row to switch live.
--   2. CRT filter (tester): a row that cycles Classic / Neon / LCD / Off
--      (crt_manager.lua), followed by that filter's own settings rows.
--      Those rows come from the `settings` table inside crt_filter.lua /
--      crt_filter2.lua / crt_filter3.lua, so adding a setting there shows
--      up here automatically.
--
-- Every row is handled by activateRow(), so mouse, keyboard and gamepad
-- share one code path (menu_input.lua needs no per-row knowledge).
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local ui_state = require(ROOT .. ".ui_state")
local helpers = require(ROOT .. ".ui.helpers")
local getFont = helpers.getFont
local texture_filter_manager = require(ROOT .. ".texture_filter_manager")
local crt_manager = require(ROOT .. ".crt_manager")

local texture_filter_menu = {}

local function buildRows()
    local rows = {}
    for i, def in ipairs(texture_filter_manager.getOptions()) do
        table.insert(rows, { type = "filter", index = i, label = string.upper(def.name) })
    end
    table.insert(rows, { type = "crt_filter", label = "CRT FILTER", gapBefore = true })
    local settingRows = crt_manager.getSettingRows(crt_manager.getActiveIndex())
    for _, s in ipairs(settingRows) do
        table.insert(rows, { type = "crt_setting", id = s.id, label = s.label })
    end
    if #settingRows > 0 then
        table.insert(rows, { type = "action", id = "crt_reset", label = "RESET CRT SETTINGS" })
    end
    table.insert(rows, { type = "action", id = "back", label = "BACK", gapBefore = true })
    return rows
end

-- Returns rows, rowHeight, rowWidth, ys (top y of every row), fit (<= 1).
-- With the CRT section open there can be a dozen rows, so everything
-- shrinks by `fit` when it wouldn't fit the window.
local function layout(screenHeight, uiScale)
    local rows = buildRows()
    local rowHeight = 64 * uiScale
    local spacing = 10 * uiScale
    local gap = 24 * uiScale

    local total = #rows * rowHeight + (#rows - 1) * spacing
    for _, row in ipairs(rows) do
        if row.gapBefore then total = total + gap end
    end

    local avail = screenHeight - 2 * 130 * uiScale -- room for title + hint
    local fit = math.min(1, avail / total)
    rowHeight, spacing, gap, total = rowHeight * fit, spacing * fit, gap * fit, total * fit

    local rowWidth = math.floor(560 * uiScale)
    local y = math.floor(screenHeight / 2 - total / 2)
    local ys = {}
    for i, row in ipairs(rows) do
        if row.gapBefore then y = y + gap end
        ys[i] = y
        y = y + rowHeight + spacing
    end
    return rows, math.floor(rowHeight), rowWidth, ys, fit, y - spacing
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

    local fontSize = math.min(24 * uiScale, rowHeight * 0.45)
    local pad = 24 * uiScale
    local textY = y + (rowHeight - fontSize) / 2
    love.graphics.setColor(r/255, g/255, b/255, alpha)
    love.graphics.setFont(getFont(fontSize))
    love.graphics.printf(label, centerX - rowWidth / 2 + pad, textY, rowWidth * 0.5, "left")

    if valueText ~= "" then
        love.graphics.setColor(valueColor[1], valueColor[2], valueColor[3], alpha)
        love.graphics.printf(valueText, centerX - rowWidth / 2, textY, rowWidth - pad, "right")
    end
end

function texture_filter_menu.drawTextureFilterMenu(screenWidth, screenHeight, selection, mouseX, mouseY, uiScale)
    local t = helpers.getPopupTime("textureFilterMenu")

    helpers.drawMenuBackdrop(screenWidth, screenHeight, 180/255)
    local r, g, b = helpers.getRainbowColor(ui_state.getState().pulseTime)
    local centerX = math.floor(screenWidth / 2)

    local rows, rowHeight, rowWidth, ys, fit, bottomY = layout(screenHeight, uiScale)

    local titleY = ys[1] - 90 * uiScale
    local titleScale, titleAlpha = helpers.popIn(t, 0, 0.5)
    helpers.withPop(centerX, titleY + (52 * uiScale) / 2, titleScale, titleAlpha, function()
        love.graphics.setColor(r/255, g/255, b/255, titleAlpha)
        love.graphics.setFont(getFont(52 * uiScale))
        love.graphics.printf("T E X T U R E S", 0, titleY, screenWidth, "center")
    end)

    local activeIndex = texture_filter_manager.getActiveIndex()
    local crtIndex = crt_manager.getActiveIndex()
    local crtDef = crt_manager.getOptions()[crtIndex]
    local crtOff = crtDef.module == nil
    local baseDelay = 0.15
    local stagger = 0.04
    for i, row in ipairs(rows) do
        local y = ys[i]
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
            elseif row.type == "crt_filter" then
                local color = crtOff and { 0.85, 0.85, 0.85 } or { 0.4, 1, 0.5 }
                drawRow(row.label, string.upper(crtDef.name), color, centerX, y,
                    rowWidth, rowHeight, isSelected, hovered, uiScale, r, g, b, alpha)
            elseif row.type == "crt_setting" then
                drawRow(row.label, crt_manager.getSettingLabel(crtIndex, row.id), { 0.85, 0.85, 0.85 },
                    centerX, y, rowWidth, rowHeight, isSelected, hovered, uiScale, r, g, b, alpha)
            else
                helpers.drawScaledButton(row.label, centerX, y, rowWidth, rowHeight,
                    isSelected, hovered, false, uiScale * fit, r, g, b, alpha)
            end
        end)
    end

    local hintScale, hintAlpha = helpers.popIn(t, baseDelay + #rows * stagger + 0.1, 0.35)
    local hintY = bottomY + 24 * uiScale
    helpers.withPop(centerX, hintY, hintScale, hintAlpha, function()
        love.graphics.setColor(0.6, 0.6, 0.6, hintAlpha)
        love.graphics.setFont(getFont(18 * uiScale))
        love.graphics.printf("Click a row to change it -- [Esc] or [B] to go back",
            0, hintY, screenWidth, "center")
    end)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Returns:
--   { action = "select", row = <row index> }  -- pass the row to activateRow()
--   { action = "back" }
--   nil
function texture_filter_menu.handleTextureFilterMenuClick(x, y, screenWidth, screenHeight, uiScale)
    local rows, rowHeight, rowWidth, ys = layout(screenHeight, uiScale)
    local centerX = math.floor(screenWidth / 2)
    for i, row in ipairs(rows) do
        local ry = ys[i]
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
    elseif row.type == "crt_filter" then
        -- Next filter (wrapping through OFF), skipping any that failed to load.
        local count = #crt_manager.getOptions()
        local current = crt_manager.getActiveIndex()
        for step = 1, count do
            if crt_manager.select((current - 1 + step) % count + 1) then break end
        end
        -- Row count changes with the filter; keep the cursor in range.
        local s = ui_state.getState()
        s.textureFilterSelection = math.min(s.textureFilterSelection, #buildRows())
    elseif row.type == "crt_setting" then
        crt_manager.cycleSetting(row.id)
    elseif row.id == "crt_reset" then
        crt_manager.resetSettings()
    else
        return "back"
    end
    return nil
end

return texture_filter_menu
