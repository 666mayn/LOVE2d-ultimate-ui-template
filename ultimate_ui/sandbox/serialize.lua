-- sandbox/serialize.lua
-- Turns a plain Lua table (strings, numbers, booleans, nested tables) into
-- readable, hand-editable Lua source. Used by the editor for exports and for
-- remembering edits. Functions can't be written as data: bake them first
-- (see editor.bake) or serialize() raises an error.

local serialize = {}

-- Keys listed here come first (in this order) so output reads naturally.
local ORDER = { "id", "file", "api", "type", "text", "action", "fontSize", "font", "role", "radius", "dy", "color", "size", "spacing",
                "relativeTo", "offset", "showIf", "gapBefore", "pop", "delay", "stagger", "duration",
                "dim", "background", "image", "blur", "items", "widgets" }
local rank = {}
for i, k in ipairs(ORDER) do rank[k] = i end

local function isIdentifier(k)
    return type(k) == "string" and k:match("^[%a_][%w_]*$") ~= nil
        and not ({ ["and"]=1, ["break"]=1, ["do"]=1, ["else"]=1, ["elseif"]=1, ["end"]=1,
                   ["false"]=1, ["for"]=1, ["function"]=1, ["if"]=1, ["in"]=1, ["local"]=1,
                   ["nil"]=1, ["not"]=1, ["or"]=1, ["repeat"]=1, ["return"]=1, ["then"]=1,
                   ["true"]=1, ["until"]=1, ["while"]=1 })[k]
end

local function num(n)
    if n == math.floor(n) and math.abs(n) < 1e15 then return string.format("%d", n) end
    return string.format("%.6g", n)
end

local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n == #t
end

local function allNumbers(t)
    for i = 1, #t do if type(t[i]) ~= "number" then return false end end
    return true
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ra, rb = rank[a] or 1000, rank[b] or 1000
        if ra ~= rb then return ra < rb end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function write(v, indent)
    local tv = type(v)
    if tv == "string" then return (string.format("%q", v):gsub("\\\n", "\\n"))
    elseif tv == "number" then return num(v)
    elseif tv == "boolean" then return tostring(v)
    elseif tv ~= "table" then
        error("cannot serialize a " .. tv .. " value (bake functions into data first)")
    end

    if next(v) == nil then return "{}" end
    local pad = string.rep("    ", indent + 1)
    local close = string.rep("    ", indent)

    if isArray(v) then
        if allNumbers(v) and #v <= 4 then
            local parts = {}
            for i = 1, #v do parts[i] = num(v[i]) end
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
        local out = {}
        for i = 1, #v do out[i] = pad .. write(v[i], indent + 1) .. "," end
        return "{\n" .. table.concat(out, "\n") .. "\n" .. close .. "}"
    end

    local out = {}
    for _, k in ipairs(sortedKeys(v)) do
        local key = isIdentifier(k) and k or ("[" .. write(k, 0) .. "]")
        out[#out + 1] = pad .. key .. " = " .. write(v[k], indent + 1) .. ","
    end
    return "{\n" .. table.concat(out, "\n") .. "\n" .. close .. "}"
end

function serialize.serialize(value)
    return (write(value, 0))
end

return serialize
