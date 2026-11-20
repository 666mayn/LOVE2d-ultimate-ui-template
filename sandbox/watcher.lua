-- sandbox/watcher.lua
-- Polls the modification time of every .lua file in the project so edits
-- can trigger an automatic restart. Plain polling (no OS file events) keeps
-- it dependency-free and identical on Windows / macOS / Linux.
--
-- Works when LOVE runs the project from a folder (`love .`). A .love file or
-- fused build has no live files to watch -- the sandbox is a dev tool.

local watcher = {}

local snapshot = {}
local ignore = {}
local elapsed = 0

local function scan(dir, out)
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = (dir == "") and name or (dir .. "/" .. name)
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "directory" then
                if not ignore[name] then scan(path, out) end
            elseif info.type == "file" and path:match("%.lua$") then
                out[path] = info.modtime or 0
            end
        end
    end
    return out
end

-- Take the baseline snapshot. `ignoreList` is a list of folder names to skip.
function watcher.start(ignoreList)
    ignore = {}
    for _, name in ipairs(ignoreList or {}) do ignore[name] = true end
    snapshot = scan("", {})
    elapsed = 0
    return next(snapshot) ~= nil
end

function watcher.count()
    local n = 0
    for _ in pairs(snapshot) do n = n + 1 end
    return n
end

-- Call every frame. Every `interval` seconds it re-scans; returns the path
-- of a changed / added / removed file, or nil if nothing changed.
function watcher.update(dt, interval)
    elapsed = elapsed + dt
    if elapsed < interval then return nil end
    elapsed = 0

    local now = scan("", {})
    for path, mtime in pairs(now) do
        if snapshot[path] ~= mtime then return path end
    end
    for path in pairs(snapshot) do
        if now[path] == nil then return path end
    end
    return nil
end

return watcher
