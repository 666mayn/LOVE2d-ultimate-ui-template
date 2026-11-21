-- controller.lua
-- Rebindable GAMEPAD button actions. Same shape as keybinds.lua, driven by
-- ui/controller_menu.lua. Uses LOVE GamepadButtons ("a", "b", "x", "y",
-- "dpup", "leftshoulder", ...). Analog sticks are not rebindable here --
-- read them yourself with joystick:getGamepadAxis().
--
-- TO USE IN YOUR GAME
--   1. Replace the placeholder entries in ACTIONS (same ids as keybinds.lua
--      is a good idea -- input.lua then lets one call cover both devices).
--   2. In gameplay:   controller.isDown("placeholder_jump")
--                     controller.matches("placeholder_jump", button)
--   3. Rebinding is wired by menu_input.lua. Binds persist to ultimate_ui_controller.txt.
--
-- "b" is used as the global BACK button in menus, but you can still bind it
-- to gameplay actions.

local ROOT = (...):match("^(.*)%.[^.]+$")
local debuglog = require(ROOT .. ".debuglog")

local controller = {}

local ACTIONS = {
    { id = "placeholder_forward",  label = "PLACEHOLDER FORWARD",  default = "dpup" },
    { id = "placeholder_left",     label = "PLACEHOLDER LEFT",     default = "dpleft" },
    { id = "placeholder_backward", label = "PLACEHOLDER BACKWARD", default = "dpdown" },
    { id = "placeholder_right",    label = "PLACEHOLDER RIGHT",    default = "dpright" },
    { id = "placeholder_jump",     label = "PLACEHOLDER JUMP",     default = "a" },
    { id = "placeholder_action",   label = "PLACEHOLDER ACTION",   default = "x" },
    { id = "placeholder_sprint",   label = "PLACEHOLDER SPRINT",   default = "leftshoulder" },
}

controller.actionOrder = ACTIONS

local RESERVED = { start = true } -- start = pause
local SAVE_PATH = "ultimate_ui_controller.txt"

local bindings = {}
local capturingAction = nil

local function findDef(id)
    for _, def in ipairs(ACTIONS) do
        if def.id == id then return def end
    end
    return nil
end

local function copyDefaults()
    bindings = {}
    for _, def in ipairs(ACTIONS) do bindings[def.id] = def.default end
end

local DISPLAY_NAMES = {
    a = "A", b = "B", x = "X", y = "Y",
    back = "BACK", guide = "GUIDE", start = "START",
    leftstick = "L STICK", rightstick = "R STICK",
    leftshoulder = "LB", rightshoulder = "RB",
    dpup = "D-PAD UP", dpdown = "D-PAD DOWN",
    dpleft = "D-PAD LEFT", dpright = "D-PAD RIGHT",
}

-- ==========================================
-- Queries used by gameplay
-- ==========================================
function controller.getButton(id) return bindings[id] end

-- Checks every connected gamepad.
function controller.isDown(id)
    local button = bindings[id]
    if not button then return false end
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() and joystick:isGamepadDown(button) then return true end
    end
    return false
end

-- True if `button` (from love.gamepadpressed) is the button bound to `id`.
function controller.matches(id, button)
    return bindings[id] ~= nil and bindings[id] == button
end

-- ==========================================
-- Queries used by ui/controller_menu.lua
-- ==========================================
function controller.getDisplayName(id)
    local button = bindings[id]
    if not button then return "UNBOUND" end
    return DISPLAY_NAMES[button] or string.upper(button)
end

function controller.getCapturingAction() return capturingAction end
function controller.isCapturing() return capturingAction ~= nil end

function controller.startCapture(id)
    if findDef(id) then capturingAction = id end
end

function controller.cancelCapture() capturingAction = nil end

-- Feed every love.gamepadpressed button here while isCapturing() is true.
-- "start" cancels; any other button is bound (swapping with whichever
-- action already used it). Returns true if the press was consumed.
function controller.handleGamepadPressed(button)
    if not capturingAction then return false end
    if button == "start" then
        capturingAction = nil
        return true
    end
    if RESERVED[button] then return true end

    for _, def in ipairs(ACTIONS) do
        if def.id ~= capturingAction and bindings[def.id] == button then
            bindings[def.id] = bindings[capturingAction] -- swap
        end
    end
    bindings[capturingAction] = button
    capturingAction = nil
    controller.save()
    return true
end

function controller.resetToDefaults()
    copyDefaults()
    capturingAction = nil
    controller.save()
end

-- ==========================================
-- Persistence
-- ==========================================
function controller.save()
    local lines = {}
    for _, def in ipairs(ACTIONS) do
        table.insert(lines, def.id .. "=" .. tostring(bindings[def.id]))
    end
    local ok, err = pcall(love.filesystem.write, SAVE_PATH, table.concat(lines, "\n"))
    if not ok then debuglog.log("controller.save() failed: %s", tostring(err)) end
end

function controller.load()
    copyDefaults()
    if not love.filesystem.getInfo(SAVE_PATH) then return end
    local ok, contents = pcall(love.filesystem.read, SAVE_PATH)
    if not ok or not contents then return end
    for line in contents:gmatch("[^\r\n]+") do
        local id, button = line:match("^([%w_]+)=(.+)$")
        if id and button and findDef(id) and not RESERVED[button] then
            bindings[id] = button
        end
    end
end

function controller.init()
    controller.load()
end

return controller
