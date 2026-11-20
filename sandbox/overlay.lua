-- sandbox/overlay.lua
-- Draws the sandbox's on-screen tooling on top of your game: a one-line
-- status strip, the F1 panel, and the event log. Purely presentational --
-- init.lua hands it ready-made text via `info`:
--
--   info.strip   string   always-visible line, bottom-left
--   info.toast   string?  most recent message (fades out), above the strip
--   info.rows    table?   F1 panel rows: { heading = "..." } or { key =, value = }
--   info.log     table?   event-log lines, oldest first
--
-- It uses its own small font and push("all")/pop, so it can't disturb the
-- UI being tested (colors, fonts, transforms all restored afterwards).

local overlay = {}

local font

local COLORS = {
    heading = { 1.00, 0.76, 0.12 },
    key     = { 0.50, 1.00, 0.60 },
    value   = { 0.92, 0.92, 0.92 },
    strip   = { 0.85, 0.85, 0.85 },
    toast   = { 1.00, 0.76, 0.12 },
    log     = { 0.70, 0.78, 0.90 },
}

local function box(x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", x, y, w, h)
end

local function text(str, x, y, c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
    love.graphics.print(str, x, y)
end

function overlay.draw(info)
    if not font then font = love.graphics.newFont(13) end

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setFont(font)

    local w, h = love.graphics.getDimensions()
    local lh = font:getHeight() + 3
    local pad = 8
    local y = h - pad

    -- Status strip (bottom-left)
    local stripW = font:getWidth(info.strip) + pad * 2
    y = y - (lh + pad)
    box(pad, y, stripW, lh + pad)
    text(info.strip, pad * 2, y + pad / 2, COLORS.strip)

    -- Toast (fades during its last second)
    if info.toast then
        local toastW = font:getWidth(info.toast.text) + pad * 2
        y = y - (lh + pad) - 2
        box(pad, y, toastW, lh + pad)
        text(info.toast.text, pad * 2, y + pad / 2, COLORS.toast, info.toast.alpha)
    end

    -- Event log (newest at the bottom, stacked upward)
    if info.log and #info.log > 0 then
        local maxLines = math.max(1, math.min(#info.log, math.floor((y - 20) / lh)))
        local first = #info.log - maxLines + 1
        local widest = 0
        for i = first, #info.log do
            widest = math.max(widest, font:getWidth(info.log[i]))
        end
        local logH = maxLines * lh + pad
        y = y - logH - 2
        box(pad, y, widest + pad * 2, logH)
        for i = first, #info.log do
            text(info.log[i], pad * 2, y + pad / 2 + (i - first) * lh, COLORS.log)
        end
    end

    -- F1 panel (top-right)
    if info.rows then
        local panelW = 400
        local keyW = 118
        local x = w - panelW - pad
        local panelH = #info.rows * lh + pad * 2
        box(x, pad, panelW, panelH)
        for i, row in ipairs(info.rows) do
            local ry = pad * 2 + (i - 1) * lh - 2
            if row.heading then
                text(row.heading, x + pad, ry, COLORS.heading)
            else
                text(row.key, x + pad, ry, COLORS.key)
                text(row.value, x + pad + keyW, ry, COLORS.value)
            end
        end
    end

    love.graphics.pop()
end

return overlay
