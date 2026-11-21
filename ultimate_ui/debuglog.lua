-- debuglog.lua
-- Tiny print-based logger. Everything in the library reports through here, so
-- replace the body with file logging, an on-screen console, etc. if you want.
--
--   debuglog.log(fmt, ...)            plain message           ->  [log] ...
--   debuglog.warn(fmt, ...)           something is wrong      ->  [log] WARNING: ...
--   debuglog.warnOnce(key, fmt, ...)  same, but only the first time `key` is seen
--   debuglog.warnings                 every warning raised this run (list of strings)
--
-- WHERE IT SHOWS UP
--   Output goes through print(), i.e. standard output:
--     * Windows: run the game with lovec.exe (the console build of LOVE), or set
--       `t.console = true` in conf.lua, and a console window shows everything live.
--     * Linux / macOS: run `love .` from a terminal.
--     * Sandbox (love . --sandbox): the same lines also appear in its on-screen log (F4).
--   stdout is switched to unbuffered below so lines appear the moment they happen,
--   even when the output is piped or the game crashes right after.

local debuglog = {}

debuglog.enabled = true
debuglog.warnings = {}

local seen = {}

-- Without this, a console build can hold lines back until the buffer fills.
pcall(function() io.stdout:setvbuf("no") end)

local function format(fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    return ok and msg or tostring(fmt)
end

function debuglog.log(fmt, ...)
    if not debuglog.enabled then return end
    print("[log] " .. format(fmt, ...))
end

-- Goes through debuglog.log on purpose, so anything that hooks log() (the sandbox's
-- on-screen log) sees warnings too.
function debuglog.warn(fmt, ...)
    local msg = format(fmt, ...)
    debuglog.warnings[#debuglog.warnings + 1] = msg
    debuglog.log("WARNING: %s", msg)
end

function debuglog.warnOnce(key, fmt, ...)
    if seen[key] then return end
    seen[key] = true
    debuglog.warn(fmt, ...)
end

return debuglog
