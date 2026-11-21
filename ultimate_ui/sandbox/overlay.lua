-- sandbox/overlay.lua
-- Draws the sandbox's on-screen tooling on top of your game: a one-line
-- status strip, the F1 panel, and the event log. Purely presentational --
-- init.lua hands it ready-made text via `info`:
--
--   info.strip   string   always-visible line, bottom-left
--   info.hints   table?   extra hint lines stacked directly above the strip (editor mode)
--   info.toast   string?  most recent message (fades out), above the strip
--   info.rows    table?   F1 panel rows: { heading = "..." } or { key =, value = }
--   info.log     table?   event-log lines, oldest first
--
-- It uses the template font (via sandbox/theme.lua) and push("all")/pop, so it can't disturb the
-- UI being tested (colors, fonts, transforms all restored afterwards).

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local theme = require(ROOT .. ".sandbox.theme")

local overlay = {}

local COLORS = {
    heading = { 1.00, 0.76, 0.12 },
    key     = { 0.50, 1.00, 0.60 },
    value   = { 0.92, 0.92, 0.92 },
    strip   = { 0.85, 0.85, 0.85 },
    hint    = { 0.55, 0.90, 1.00 },
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

-- push("all") SAVES the graphics state but does not reset it, so anything the game left
-- behind (a canvas, shader, scissor, blend mode, color mask, stencil) would apply to the
-- overlay too and could hide it -- most often in the game state, where the world and the
-- screen filter are drawn. Put everything back to plain defaults first.
function overlay.cleanState()
    -- Each call is protected on its own: one that a LOVE version dislikes must never stop
    -- the rest (or the overlay itself) from running.
    local g = love.graphics
    pcall(g.setCanvas)
    pcall(g.setShader)
    pcall(g.setScissor)
    pcall(g.setBlendMode, "alpha")
    pcall(g.setColorMask, true, true, true, true)
    pcall(g.setStencilTest)
    pcall(g.setWireframe, false)
    pcall(g.setLineWidth, 1)
    pcall(g.setLineStyle, "rough")
    pcall(g.origin)
end

function overlay.draw(info)
    local font = theme.font()

    love.graphics.push("all")
    overlay.cleanState()
    love.graphics.setFont(font)

    local w, h = love.graphics.getDimensions()
    local lh = font:getHeight() + 4
    local pad = math.max(8, math.floor(font:getHeight() / 2))
    local y = h - pad

    -- Status strip (bottom-left)
    local stripW = font:getWidth(info.strip) + pad * 2
    y = y - (lh + pad)
    box(pad, y, stripW, lh + pad)
    text(info.strip, pad * 2, y + pad / 2, COLORS.strip)

    -- Hint lines (editor mode), bottom line closest to the strip
    if info.hints then
        for i = #info.hints, 1, -1 do
            local hw = font:getWidth(info.hints[i]) + pad * 2
            y = y - (lh + pad) - 2
            box(pad, y, hw, lh + pad)
            text(info.hints[i], pad * 2, y + pad / 2, COLORS.hint)
        end
    end

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

    -- F1 panel (top-right). Two even columns -- key, then description -- sized to
    -- the widest entry so nothing runs off the edge.
    if info.rows then
        local gap = pad * 2
        local keyW, valW = 0, 0
        for _, row in ipairs(info.rows) do
            if not row.heading then
                keyW = math.max(keyW, font:getWidth(row.key))
                valW = math.max(valW, font:getWidth(row.value))
            end
        end
        local panelW = math.min(w - pad * 2, pad * 2 + keyW + gap + valW)
        local x = w - panelW - pad
        local panelH = #info.rows * lh + pad * 2
        box(x, pad, panelW, panelH)
        for i, row in ipairs(info.rows) do
            local ry = pad + pad / 2 + (i - 1) * lh
            if row.heading then
                text(row.heading, x + pad, ry, COLORS.heading)
            else
                text(row.key, x + pad, ry, COLORS.key)
                text(row.value, x + pad + keyW + gap, ry, COLORS.value)
            end
        end
    end

    love.graphics.pop()
end

return overlay
