-- loading_screen.lua
-- Generic "hold a spinner for at least N seconds while something resolves"
-- state machine. It knows nothing about your game: callers pass in a target
-- name, an optional "is it still waiting on something" check, and an
-- optional onFinish callback.
--
--   loading_screen.configure({
--       onStart        = function(target) end,   -- e.g. play a sound
--       isStillWaiting = function(target) return false end, -- e.g. async load
--       onFinish       = function(target) ... end,
--   })
--   loading_screen.start("game", 1.5, "LOADING...")
--   -- each frame: if loading_screen.update(dt) then (skip normal updates) end
--   -- draw with ui.drawLoadingScreen(w, h, uiScale, state.loadTimer, state.loadTimerMax, state.loadLabel)

local loading_screen = {}

local DEFAULTS = {
    isLoading = false,
    loadTimer = 0,
    loadTimerMax = 2.0,
    loadTarget = nil,   -- caller-defined string, e.g. "game" | "level2"
    loadLabel = "LOADING...",
}

local state = {}
for k, v in pairs(DEFAULTS) do state[k] = v end

local onStart = nil
local isStillWaiting = nil
local onFinish = nil
local holdWhile = nil   -- optional dev hook: while it returns true the screen just stays up

function loading_screen.getState() return state end

-- Dev hook (the sandbox editor uses it): while fn() returns true the loading screen stays up
-- with its timer frozen, so its title can be edited. Pass nil to remove. A game never needs it.
function loading_screen.holdWhile(fn) holdWhile = fn end

function loading_screen.init()
    for k, v in pairs(DEFAULTS) do state[k] = v end
end

-- Registers the shared callbacks used by start()/update(). Call once at startup.
function loading_screen.configure(opts)
    onStart = opts.onStart
    isStillWaiting = opts.isStillWaiting
    onFinish = opts.onFinish
end

-- Starts the loading screen for `target`, holding for at least `duration`
-- seconds (defaults to 2.0) and showing `label` (defaults to "LOADING...").
function loading_screen.start(target, duration, label)
    state.isLoading = true
    state.loadTimer = duration or 2.0
    state.loadTimerMax = state.loadTimer
    state.loadTarget = target
    state.loadLabel = label or "LOADING..."
    if onStart then onStart(target) end
end

-- Returns true while the loading screen is active (and should therefore
-- block/override normal per-frame update logic upstream).
function loading_screen.update(dt)
    if not state.isLoading then return false end
    if holdWhile and holdWhile() then return true end

    state.loadTimer = state.loadTimer - dt
    if state.loadTimer <= 0 then
        state.loadTimer = 0

        local target = state.loadTarget
        if isStillWaiting and isStillWaiting(target) then
            -- Minimum display time is up but the async op hasn't resolved
            -- yet -- keep the loading screen showing instead of finishing.
            return true
        end

        state.isLoading = false
        state.loadTarget = nil
        if onFinish then onFinish(target) end
    end

    return true
end

return loading_screen
