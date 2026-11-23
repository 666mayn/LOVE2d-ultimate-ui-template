-- ui/helpers.lua
-- Shared low-level drawing + pop-in animation helpers used across every
-- screen in the ui/ package. Nothing in here knows about game state; it's
-- pure presentation plumbing.
local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local fonts = require(ROOT .. ".fonts")
local background = require(ROOT .. ".ui.background")

local helpers = {}

-- Every ui/ file pulls its font lookup from here (local getFont = helpers.getFont)
-- so the template never relies on a global function. Swap this one line if you
-- want to route text through your own font system.
helpers.getFont = fonts.get
local getFont = helpers.getFont

function helpers.getRainbowColor(time)
    local r = math.abs(math.sin(time * 2)) * 255
    local g = math.abs(math.sin(time * 2 + 2)) * 255
    local b = math.abs(math.sin(time * 2 + 4)) * 255
    return r, g, b
end

-- Pop-in animation helper: returns (scale, alpha) for an element that should
-- animate in starting at `delay` seconds after the menu opened, over
-- `duration` seconds. Uses an "ease out back" curve so it overshoots
-- slightly past 1.0 before settling -- a little bounce/pop rather than a
-- flat fade. Scale/alpha are both 0 before `delay` has elapsed.
function helpers.popIn(t, delay, duration)
    duration = duration or 0.45
    local elapsed = t - delay
    if elapsed <= 0 then return 0, 0 end
    local p = math.min(elapsed / duration, 1)
    local alpha = math.min(elapsed / (duration * 0.6), 1)
    local c1 = 1.70158
    local c3 = c1 + 1
    local scale = 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
    return scale, alpha
end

-- Wraps a draw callback in a scale+pivot transform driven by popIn()'s
-- scale value, so a title, button, or entire block of content can "pop"
-- in around its own center. Skips the draw entirely once alpha is ~0 so
-- nothing renders before its delay has elapsed.
function helpers.withPop(pivotX, pivotY, scale, alpha, drawFn)
    if alpha <= 0.001 then return end
    love.graphics.push()
    love.graphics.translate(pivotX, pivotY)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-pivotX, -pivotY)
    drawFn()
    love.graphics.pop()
end

-- Backdrop for a full-screen menu page: the shared menu background (see
-- ui/background.lua, config.menuBackground) if there is one, then the black dim.
-- With a shared background the dim is its `dim` (or `fallbackDim`), so every page
-- looks the same; without one it is just the page's own `fallbackDim` overlay.
function helpers.drawMenuBackdrop(screenWidth, screenHeight, fallbackDim)
    local spec = background.shared()
    local dim = fallbackDim
    if spec then
        background.draw(spec, screenWidth, screenHeight)
        dim = spec.dim or fallbackDim
    end
    if dim and dim > 0 then
        love.graphics.setColor(0, 0, 0, dim)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- y for love.graphics.print / printf that centers CAPITALS (in the current font) in a box.
-- Fonts place their letters differently inside the line box, so this measures instead of guessing.
helpers.textY = function(boxY, boxH) return fonts.textY(boxY, boxH, love.graphics.getFont()) end

-- Helper for drawing scaled buttons
-- `fontName` (optional) picks this one button's font; otherwise the "button" role / project font is used.
function helpers.drawScaledButton(text, centerX, y, buttonWidth, buttonHeight, isSelected, isHovered, anyHovered, uiScale, r, g, b, alpha, fontName)
    alpha = alpha or 1
    if isHovered or (isSelected and not anyHovered) then
        love.graphics.setColor(80/255, 80/255, 80/255, alpha)
        love.graphics.rectangle("fill", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("line", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
    else
        love.graphics.setColor(50/255, 50/255, 50/255, alpha)
        love.graphics.rectangle("fill", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
        love.graphics.setColor(100/255, 100/255, 100/255, alpha)
        love.graphics.rectangle("line", centerX - buttonWidth / 2, y, buttonWidth, buttonHeight)
    end
    love.graphics.setColor(r/255, g/255, b/255, alpha)

    love.graphics.setFont(getFont(36 * uiScale, "button", fontName))
    love.graphics.printf(text, centerX - buttonWidth / 2, helpers.textY(y, buttonHeight), buttonWidth, "center")
end

-- Tracks pop-in animation timers for each named popup/menu, keyed by a
-- unique string per screen (e.g. "mainMenu", "settingsMenu", "pauseMenu").
-- We don't get explicit open/close events from main.lua, so we infer them:
-- each draw function is called every frame while its screen is visible
-- (~every 0.016s at 60fps). If there's a bigger gap than that since the
-- last call for that name, the screen must have just (re)opened, so the
-- animation restarts from 0.
local _popupTimers = {}

-- Explicitly restarts a named popup's pop-in animation. Called by main.lua
-- at the exact moment a menu/popup is opened (button click, key press,
-- gamepad press), rather than relying purely on inferring it from draw-call
-- gaps -- this is more robust since it can't be thrown off by frame timing.
function helpers.resetPopupAnimation(name)
    _popupTimers[name] = nil
end

function helpers.getPopupTime(name)
    local now = love.timer.getTime()
    local timer = _popupTimers[name]
    if not timer then
        timer = { lastDraw = now, openedAt = now }
        _popupTimers[name] = timer
    elseif (now - timer.lastDraw) > 0.1 then
        timer.openedAt = now
    end
    timer.lastDraw = now
    return now - timer.openedAt
end

-- Draws a button scaled+faded in around its own center using popIn(), rather
-- than the whole screen's origin, so it pops in place instead of sliding.
function helpers.drawPoppedButton(text, centerX, y, buttonWidth, buttonHeight, isSelected, isHovered, anyHovered, uiScale, r, g, b, t, delay, fontName)
    local scale, alpha = helpers.popIn(t, delay, 0.4)
    helpers.withPop(centerX, y + buttonHeight / 2, scale, alpha, function()
        helpers.drawScaledButton(text, centerX, y, buttonWidth, buttonHeight, isSelected, isHovered, anyHovered, uiScale, r, g, b, alpha, fontName)
    end)
end

return helpers
