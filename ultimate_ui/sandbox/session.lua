-- sandbox/session.lua
-- Remembers sandbox state (current screen, window size, toggles) in the save
-- folder, so a restart -- manual or from auto-reload -- puts you right back
-- where you were instead of at the main menu.

local session = {}

local PATH = "ultimate_ui_sandbox_session.txt"

-- `values` is a flat table of string/number/boolean values.
function session.save(values)
    local lines = {}
    for k, v in pairs(values) do
        if type(v) == "boolean" then v = v and "1" or "0" end
        lines[#lines + 1] = k .. "=" .. tostring(v)
    end
    table.sort(lines)
    pcall(love.filesystem.write, PATH, table.concat(lines, "\n"))
end

-- Returns a table of strings (empty if nothing saved yet).
function session.load()
    local out = {}
    if not love.filesystem.getInfo(PATH) then return out end
    local ok, contents = pcall(love.filesystem.read, PATH)
    if not ok or not contents then return out end
    for line in contents:gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_]+)=(.*)$")
        if k then out[k] = v end
    end
    return out
end

return session
