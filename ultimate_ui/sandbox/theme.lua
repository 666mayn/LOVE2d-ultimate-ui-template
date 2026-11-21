-- sandbox/theme.lua
-- Look shared by the sandbox's own tooling (the editor panel). Plain data + a few
-- tiny draw helpers; nothing here touches the game's UI.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local theme = {}

theme.PAD = 10

theme.color = {
    heading = { 1.00, 0.76, 0.12 },
    value   = { 0.92, 0.92, 0.92 },
    muted   = { 0.62, 0.64, 0.70 },
    select  = { 1.00, 0.76, 0.12 },   -- selected widget outline / focused field
    error   = { 1.00, 0.38, 0.38 },
}

-- The template's own font (whatever .ttf/.otf is in fonts/, see fonts.lua), so the
-- tooling matches the UI. Sized from the window height (16px at 1080p) in even
-- steps, which keeps pixel fonts crisp.
local cache = {}
function theme.font(size)
    size = size or math.max(12, math.floor(love.graphics.getHeight() / 1080 * 16 / 2 + 0.5) * 2)
    if not cache[size] then cache[size] = require(ROOT .. ".fonts").new(size) end
    return cache[size]
end

-- Dark translucent box.
function theme.panel(x, y, w, h, alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.85)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

function theme.print(str, x, y, c)
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
    love.graphics.print(str, math.floor(x), math.floor(y))
end

return theme
