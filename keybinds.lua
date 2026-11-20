-- keybinds.lua
-- Rebindable KEYBOARD actions. Pure data + a click-to-rebind capture flow,
-- no drawing code (ui/keyboard_menu.lua draws it).
--
-- TO USE IN YOUR GAME
--   1. Replace the placeholder entries in ACTIONS with your own (the `id`
--      is what your gameplay code asks about; `label` is what the menu
--      shows; `default` is a LOVE KeyConstant).
--   2. In gameplay:   if keybinds.isDown("placeholder_forward") then ... end
--      or for one-shot actions in love.keypressed:
--                     if keybinds.matches("placeholder_jump", key) then ... end
--   3. Rebinding is wired up by menu_input.lua (it calls startCapture /
--      handleKeyPressed for you). Binds persist to keybinds.txt.
--
-- Esc is reserved for pause / back and cannot be bound.

local debuglog = require("debuglog")

local keybinds = {}

local ACTIONS = {
    { id = "placeholder_forward",  label = "PLACEHOLDER FORWARD",  default = "w" },
    { id = "placeholder_left",     label = "PLACEHOLDER LEFT",     default = "a" },
    { id = "placeholder_backward", label = "PLACEHOLDER BACKWARD", default = "s" },
    { id = "placeholder_right",    label = "PLACEHOLDER RIGHT",    default = "d" },
    { id = "placeholder_jump",     label = "PLACEHOLDER JUMP",     default = "space" },
    { id = "placeholder_action",   label = "PLACEHOLDER ACTION",   default = "e" },
    { id = "placeholder_sprint",   label = "PLACEHOLDER SPRINT",   default = "lshift" },
}

keybinds.actionOrder = ACTIONS

local RESERVED = { escape = true }
local SAVE_PATH = "keybinds.txt"

local bindings = {}          -- id -> key
local capturingAction = nil  -- id currently waiting for a key press, or nil

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

-- Friendlier names for the menu; anything not listed is just uppercased.
local DISPLAY_NAMES = {
    space = "SPACE", lshift = "L SHIFT", rshift = "R SHIFT",
    lctrl = "L CTRL", rctrl = "R CTRL", lalt = "L ALT", ralt = "R ALT",
    ["return"] = "ENTER", tab = "TAB", backspace = "BACKSPACE",
    up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT",
    ["-"] = "MINUS", ["="] = "EQUALS",
}

-- ==========================================
-- Queries used by gameplay
-- ==========================================
function keybinds.getKey(id) return bindings[id] end

function keybinds.isDown(id)
    local key = bindings[id]
    return key ~= nil and love.keyboard.isDown(key)
end

-- True if `key` (from love.keypressed) is the key bound to `id`.
function keybinds.matches(id, key)
    return bindings[id] ~= nil and bindings[id] == key
end

-- ==========================================
-- Queries used by ui/keyboard_menu.lua
-- ==========================================
function keybinds.getDisplayName(id)
    local key = bindings[id]
    if not key then return "UNBOUND" end
    return DISPLAY_NAMES[key] or string.upper(key)
end

function keybinds.getCapturingAction() return capturingAction end
function keybinds.isCapturing() return capturingAction ~= nil end

function keybinds.startCapture(id)
    if findDef(id) then capturingAction = id end
end

function keybinds.cancelCapture() capturingAction = nil end

-- Feed every love.keypressed key here while isCapturing() is true.
-- Esc cancels; any other key is bound (swapping with whichever action
-- already used it, so no two actions ever share a key). Returns true if
-- the key press was consumed.
function keybinds.handleKeyPressed(key)
    if not capturingAction then return false end
    if key == "escape" then
        capturingAction = nil
        return true
    end
    if RESERVED[key] then return true end

    for _, def in ipairs(ACTIONS) do
        if def.id ~= capturingAction and bindings[def.id] == key then
            bindings[def.id] = bindings[capturingAction] -- swap
        end
    end
    bindings[capturingAction] = key
    capturingAction = nil
    keybinds.save()
    return true
end

function keybinds.resetToDefaults()
    copyDefaults()
    capturingAction = nil
    keybinds.save()
end

-- ==========================================
-- Persistence
-- ==========================================
function keybinds.save()
    local lines = {}
    for _, def in ipairs(ACTIONS) do
        table.insert(lines, def.id .. "=" .. tostring(bindings[def.id]))
    end
    local ok, err = pcall(love.filesystem.write, SAVE_PATH, table.concat(lines, "\n"))
    if not ok then debuglog.log("keybinds.save() failed: %s", tostring(err)) end
end

function keybinds.load()
    copyDefaults()
    if not love.filesystem.getInfo(SAVE_PATH) then return end
    local ok, contents = pcall(love.filesystem.read, SAVE_PATH)
    if not ok or not contents then return end
    for line in contents:gmatch("[^\r\n]+") do
        local id, key = line:match("^([%w_]+)=(.+)$")
        if id and key and findDef(id) and not RESERVED[key] then
            bindings[id] = key
        end
    end
end

function keybinds.init()
    keybinds.load()
end

return keybinds
