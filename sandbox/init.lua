-- sandbox/init.lua
-- A development sandbox for this UI template. Run it with:
--
--     love . --sandbox          (or:  UI_SANDBOX=1 love .)
--
-- It wraps your game's love.* callbacks from the OUTSIDE -- nothing in the UI
-- modules knows it exists -- and adds the tooling you want while building
-- menus: jump to any screen, a fake gamepad, window-size presets, an event
-- log, restart-and-restore, screenshots. Press F1 in the running game.
--
-- Hooked up by two lines at the bottom of main.lua. Delete those lines and
-- this folder before you ship; nothing else depends on it.
--
-- Files:  config.lua   hotkeys, presets, defaults (edit me)
--         screens.lua  jump-to-screen logic
--         overlay.lua  drawing: status strip, F1 panel, log
--         watcher.lua  auto-reload on file change
--         session.lua  remembers screen / window across restarts

local config = require("sandbox.config")

local sandbox = {}
local attached = false

-- True if the user asked for the sandbox (flag or environment variable).
function sandbox.requested(args)
    local env = os.getenv("UI_SANDBOX")
    if env and env ~= "" and env ~= "0" then return true end
    if type(args) == "table" then
        for _, v in pairs(args) do
            if v == "--sandbox" then return true end
        end
    end
    return false
end

function sandbox.attach()
    if attached then return end
    attached = true

    local ui_state = require("ui_state")
    local menu_input = require("menu_input")
    local keybinds = require("keybinds")
    local controller = require("controller")
    local other_settings = require("other_settings")
    local texture_filter_manager = require("texture_filter_manager")
    local intro_sequence = require("intro_sequence")
    local loading_screen = require("loading_screen")
    local debuglog = require("debuglog")
    local screens = require("sandbox.screens")
    local overlay = require("sandbox.overlay")
    local session = require("sandbox.session")
    local watcher = require("sandbox.watcher")

    -- ------------------------------------------------------------------
    -- State
    -- ------------------------------------------------------------------
    local clock = 0
    local panelOpen = false
    local showLog = false
    local hidden = false
    local padMode = false
    local autoReload = config.autoReload
    local pendingShot = nil          -- filename waiting for the next frame
    local wipeArmedUntil = 0
    local virtualDown = {}           -- gamepad buttons "held" by the fake pad
    local lines = {}                 -- event-log ring buffer
    local toast, toastAt = nil, 0
    local presets = {}               -- config.presets that fit this desktop
    local orig = {}                  -- the game's own callbacks

    -- key -> action, built from config.keys
    local hotkeyOf = {}
    for action, keys in pairs(config.keys) do
        for _, k in ipairs(keys) do hotkeyOf[k] = action end
    end

    -- ------------------------------------------------------------------
    -- Logging
    -- ------------------------------------------------------------------
    local function push(msg)
        lines[#lines + 1] = msg
        if #lines > 200 then table.remove(lines, 1) end
    end

    -- Message to console + log + toast.
    local function log(fmt, ...)
        local ok, msg = pcall(string.format, tostring(fmt), ...)
        msg = ok and msg or tostring(fmt)
        print("[sandbox] " .. msg)
        push(msg)
        toast, toastAt = msg, clock
    end

    -- Log-only (noisy things like every key press).
    local function event(fmt, ...)
        local ok, msg = pcall(string.format, tostring(fmt), ...)
        push(ok and msg or tostring(fmt))
    end

    -- Mirror the template's own debuglog.log() calls into the on-screen log.
    local origDebugLog = debuglog.log
    debuglog.log = function(fmt, ...)
        local ok, msg = pcall(string.format, tostring(fmt), ...)
        push("[game] " .. (ok and msg or tostring(fmt)))
        return origDebugLog(fmt, ...)
    end

    -- ------------------------------------------------------------------
    -- Window presets
    -- ------------------------------------------------------------------
    local function buildPresets()
        local dw, dh = love.window.getDesktopDimensions()
        presets = {}
        for _, p in ipairs(config.presets) do
            if p[1] <= dw and p[2] <= dh then presets[#presets + 1] = p end
        end
    end

    local function setWindowSize(w, h)
        if love.window.getFullscreen() then
            log("leave fullscreen first (Settings > Other > Fullscreen)")
            return false
        end
        love.window.updateMode(w, h, {})
        -- main.lua recomputes its UI scale in love.resize; make sure it ran.
        if love.resize then love.resize(love.graphics.getDimensions()) end
        return true
    end

    local function cycleWindowSize()
        if #presets == 0 then return log("no presets fit this desktop") end
        local cw, ch = love.graphics.getDimensions()
        local nextIndex = 1
        for i, p in ipairs(presets) do
            if p[1] == cw and p[2] == ch then nextIndex = i % #presets + 1 break end
        end
        local p = presets[nextIndex]
        if setWindowSize(p[1], p[2]) then log("window %dx%d", p[1], p[2]) end
    end

    -- ------------------------------------------------------------------
    -- Virtual gamepad
    -- ------------------------------------------------------------------
    -- Make controller.isDown() also see the fake pad's held buttons, so the
    -- D-pad can move the demo square exactly like real hardware would.
    local origIsDown = controller.isDown
    controller.isDown = function(id)
        if padMode then
            local button = controller.getButton(id)
            if button and virtualDown[button] then return true end
        end
        return origIsDown(id)
    end

    local function setPadMode(on)
        padMode = on
        virtualDown = {}
        log("virtual gamepad %s", on and "ON (arrows=D-pad Z=A X=B C=X V=Y Enter=Start)" or "off")
    end

    -- ------------------------------------------------------------------
    -- Session (restart / restore)
    -- ------------------------------------------------------------------
    local function saveSession()
        local w, h = love.graphics.getDimensions()
        session.save({
            screen = screens.currentId(),
            base = screens.base(),
            window = w .. "x" .. h,
            panel = panelOpen, log = showLog, hidden = hidden,
            pad = padMode, reload = autoReload,
        })
    end

    local restarting = false
    local function restart(reason)
        if restarting then return end   -- quit is async; don't ask twice
        restarting = true
        log("restarting (%s)", reason)
        saveSession()
        love.event.quit("restart")
    end

    local function restoreSession()
        local saved = config.restoreOnLaunch and session.load() or {}
        local function flag(v, default) if v == nil then return default end return v == "1" end

        panelOpen = flag(saved.panel, false)
        showLog = flag(saved.log, false)
        hidden = flag(saved.hidden, false)
        autoReload = flag(saved.reload, config.autoReload)
        if flag(saved.pad, false) then padMode = true end

        local w, h = (saved.window or ""):match("^(%d+)x(%d+)$")
        if w then
            local cw, ch = love.graphics.getDimensions()
            if tonumber(w) ~= cw or tonumber(h) ~= ch then setWindowSize(tonumber(w), tonumber(h)) end
        end

        if config.skipIntro then
            while intro_sequence.isActive() do intro_sequence.skip() end
        end

        if saved.screen and screens.isValid(saved.screen) then
            screens.jump(saved.screen, saved.base)
            log("restored screen: %s", saved.screen)
        else
            log("sandbox on -- press F1 for help")
        end
    end

    -- ------------------------------------------------------------------
    -- Hotkey actions
    -- ------------------------------------------------------------------
    local function wipeSaves()
        if clock > wipeArmedUntil then
            wipeArmedUntil = clock + 3
            return log("press %s again within 3s to wipe saved settings", string.upper(config.keys.wipe[1]))
        end
        wipeArmedUntil = 0
        for _, file in ipairs(config.saveFiles) do
            if love.filesystem.getInfo(file) then love.filesystem.remove(file) end
        end
        -- Re-run each module's own init so the running game picks up defaults.
        texture_filter_manager.init()
        keybinds.init()
        controller.init()
        other_settings.init()
        log("saved settings wiped -- everything back to defaults")
    end

    local ACTIONS = {
        panel = function() panelOpen = not panelOpen end,
        resize = cycleWindowSize,
        pad = function() setPadMode(not padMode) end,
        log = function() showLog = not showLog end,
        restart = function() restart("manual") end,
        reload = function()
            autoReload = not autoReload
            if autoReload then watcher.start(config.watchIgnore) end
            log("auto-reload %s", autoReload and "ON" or "off")
        end,
        loading = function() loading_screen.start("sandbox-preview", 3, "LOADING...") log("loading screen preview (3s)") end,
        wipe = wipeSaves,
        saveDir = function()
            local dir = love.filesystem.getSaveDirectory()
            log("save folder: %s", dir)
            love.system.openURL("file://" .. dir)
        end,
        hide = function() hidden = not hidden end,
        shot = function() pendingShot = os.date("sandbox_%Y%m%d_%H%M%S.png") end,
    }

    local function handleHotkey(key)
        local action = hotkeyOf[key]
        if action and ACTIONS[action] then
            local ok, err = pcall(ACTIONS[action])
            if not ok then log("sandbox error: %s", tostring(err)) end
            return true
        end
        -- Number keys jump to a screen, but only while the F1 panel is open.
        local target = panelOpen and config.jump[key]
        if target then
            if screens.jump(target) then log("jumped to %s", target) end
            return true
        end
        return false
    end

    -- ------------------------------------------------------------------
    -- Overlay content
    -- ------------------------------------------------------------------
    local function keyName(action)
        local k = config.keys[action] and config.keys[action][1] or "?"
        return string.upper(k)
    end

    local function buildInfo()
        local w, h = love.graphics.getDimensions()
        local id = screens.currentId()
        local info = {}

        -- Mirrors main.lua's updateUIScale(); update both if you change it.
        local uiScale = math.max(0.5, math.min(2, h / 1080))
        local flags = {}
        if padMode then flags[#flags + 1] = "PAD" end
        if autoReload then flags[#flags + 1] = "AUTO-RELOAD" end
        info.strip = string.format("SANDBOX | %s | %dx%d | %s%s",
            id, w, h, table.concat(flags, " "), (#flags > 0 and " | " or "") .. keyName("panel") .. " = help")

        if toast and clock - toastAt < 4 then
            info.toast = { text = toast, alpha = math.min(1, (4 - (clock - toastAt))) }
        end
        if showLog then info.log = lines end

        if panelOpen then
            local rows = {}
            local function heading(t) rows[#rows + 1] = { heading = t } end
            local function kv(k, v) rows[#rows + 1] = { key = k, value = tostring(v) } end

            heading("STATE")
            local base = (id ~= "game" and id ~= "main" and id ~= "pause") and (" (from " .. screens.base() .. ")") or ""
            kv("screen", id .. base)
            kv("cursor row", screens.cursor() or "-")
            local capK, capC = keybinds.getCapturingAction(), controller.getCapturingAction()
            kv("rebinding", capK and ("keyboard: " .. capK) or capC and ("pad: " .. capC) or "no")
            kv("window", string.format("%dx%d  (uiScale %.2f)", w, h, uiScale))
            kv("texture filter", texture_filter_manager.getActive().id)
            kv("gamepads", string.format("%d real, virtual %s", love.joystick.getJoystickCount(), padMode and "ON" or "off"))
            kv("mouse", string.format("%d, %d", love.mouse.getPosition()))
            kv("fps", love.timer.getFPS())
            kv("watching", autoReload and (watcher.count() .. " .lua files") or "off")

            heading("JUMP TO SCREEN")
            local keys = {}
            for k in pairs(config.jump) do keys[#keys + 1] = k end
            table.sort(keys)
            for i = 1, #keys, 2 do
                local a, b = keys[i], keys[i + 1]
                kv(a .. "  " .. config.jump[a], b and (b .. "  " .. config.jump[b]) or "")
            end

            heading("HOTKEYS")
            kv(keyName("resize"), "cycle window size")
            kv(keyName("pad"), "virtual gamepad on/off")
            kv(keyName("log"), "event log on/off")
            kv(keyName("restart"), "restart (reload all code)")
            kv(keyName("reload"), "auto-reload on file save")
            kv(keyName("loading"), "preview loading screen")
            kv(keyName("wipe"), "wipe saved settings (press twice)")
            kv(keyName("saveDir"), "open save folder")
            kv(keyName("hide"), "hide / show this overlay")
            kv(keyName("shot"), "screenshot (without overlay)")
            info.rows = rows
        end
        return info
    end

    -- ------------------------------------------------------------------
    -- love.* wrappers. Each runs sandbox logic, then the game's own callback.
    -- ------------------------------------------------------------------
    orig.load = love.load
    love.load = function(...)
        if orig.load then orig.load(...) end
        buildPresets()
        love.window.setTitle(love.window.getTitle() .. "  [SANDBOX]")
        local ok, err = pcall(restoreSession)
        if not ok then log("could not restore session: %s", tostring(err)) end
        watcher.start(config.watchIgnore)
    end

    orig.update = love.update
    love.update = function(dt)
        clock = clock + dt
        if autoReload then
            local changed = watcher.update(dt, config.watchInterval)
            if changed then return restart(changed .. " changed") end
        end
        if orig.update then orig.update(dt) end
    end

    orig.draw = love.draw
    love.draw = function()
        if orig.draw then orig.draw() end
        if pendingShot then
            -- Grab the frame before the overlay is drawn, so it's clean.
            love.graphics.captureScreenshot(pendingShot)
            log("screenshot: %s/%s", love.filesystem.getSaveDirectory(), pendingShot)
            pendingShot = nil
            return
        end
        if not hidden then overlay.draw(buildInfo()) end
    end

    orig.keypressed = love.keypressed
    love.keypressed = function(key, scancode, isrepeat)
        -- While a keyboard rebind waits for a key, EVERY key (F-keys included)
        -- belongs to it, so the sandbox stays out of the way.
        if not keybinds.isCapturing() then
            if not isrepeat then event("key  %s", key) end
            if handleHotkey(key) then return end
            local button = padMode and config.padMap[key]
            if button then
                virtualDown[button] = true
                if love.gamepadpressed then love.gamepadpressed(nil, button) end
                return
            end
        end
        if orig.keypressed then orig.keypressed(key, scancode, isrepeat) end
    end

    orig.keyreleased = love.keyreleased
    love.keyreleased = function(key, scancode)
        local button = padMode and config.padMap[key]
        if button then virtualDown[button] = nil end
        if orig.keyreleased then orig.keyreleased(key, scancode) end
    end

    orig.mousepressed = love.mousepressed
    love.mousepressed = function(x, y, button, ...)
        event("mouse %d  at %d,%d  (%s)", button, x, y, screens.currentId())
        if orig.mousepressed then orig.mousepressed(x, y, button, ...) end
    end

    orig.gamepadpressed = love.gamepadpressed
    love.gamepadpressed = function(joystick, button)
        event("pad  %s%s", button, joystick and "" or "  (virtual)")
        if orig.gamepadpressed then orig.gamepadpressed(joystick, button) end
    end

    orig.quit = love.quit
    love.quit = function(...)
        saveSession()
        if orig.quit then return orig.quit(...) end
    end
end

return sandbox
