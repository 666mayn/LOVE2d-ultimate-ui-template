-- debuglog.lua
-- Tiny print-based logger. Replace the body with file logging, an
-- on-screen console, etc. if you want -- everything else just calls log().

local debuglog = {}

debuglog.enabled = true

function debuglog.log(fmt, ...)
    if not debuglog.enabled then return end
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    print("[log] " .. (ok and msg or tostring(fmt)))
end

return debuglog
