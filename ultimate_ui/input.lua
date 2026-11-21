-- input.lua
-- Optional convenience: one call that checks keyboard AND gamepad for the
-- same action id, so gameplay code doesn't care which device is in use.
-- Works because keybinds.lua and controller.lua share action ids.
--
--   if input.isDown("placeholder_forward") then player.y = player.y - speed * dt end
--   function love.keypressed(key) if input.pressedKey("placeholder_jump", key) then ... end end

local ROOT = (...):match("^(.*)%.[^.]+$")
local keybinds = require(ROOT .. ".keybinds")
local controller = require(ROOT .. ".controller")

local input = {}

function input.isDown(id)
    return keybinds.isDown(id) or controller.isDown(id)
end

-- For love.keypressed(key)
function input.pressedKey(id, key)
    return keybinds.matches(id, key)
end

-- For love.gamepadpressed(joystick, button)
function input.pressedButton(id, button)
    return controller.matches(id, button)
end

return input
