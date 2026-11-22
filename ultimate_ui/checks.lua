-- checks.lua
-- Startup self-check. Looks for the things that most often go wrong when the
-- template is dropped into a new project, and says so in plain words -- once,
-- at startup -- instead of the menus quietly looking wrong.
--
--   UI.init() runs it for you.  Run it yourself with UI.checks.run().
--   Turn it off with  config.startupChecks = false  (config.lua).
--
-- What it checks
--   * menuBackground     image missing / won't decode, blur or dim out of range
--   * fonts              no .ttf/.otf in fonts/, or config.font names a missing file
--   * CRT filters        none (or some) of crt_filters/ present, or a filter file
--                        that crt_manager.lua doesn't list
--   * intro videos       a file in config.introVideos is missing / not .ogv
--   * sounds             a ui.* / loading.* file in sounds/ that will not decode, or has an
--                        extension LOVE can't use (only .ogg / .mp3 / .wav are picked up)
--   * save folder        can't write there (settings would not persist)
--   * LOVE version       the template targets LOVE 11.x
--   * sandbox            still in the folder of a fused (shipped) build
--
-- Every finding goes through debuglog.warn(), so it shows in the console (lovec.exe,
-- or `t.console = true`) and in the sandbox's on-screen log. The list of warnings is
-- also kept in debuglog.warnings.
--
-- Nothing here ever throws: a check that errors is reported as a warning and skipped.

local ROOT = (...):match("^(.*)%.[^.]+$")
local debuglog = require(ROOT .. ".debuglog")

local DIR = (ROOT:gsub("%.", "/"))     -- this folder, from the game root
local fs = love.filesystem

local checks = {}

-- ------------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------------
local function exists(path)
    return fs.getInfo(path) ~= nil
end

local function isFile(path)
    local info = fs.getInfo(path)
    return info ~= nil and info.type == "file"
end

-- File names in `dir` whose lowercase name matches any of `patterns` (sorted).
local function listFiles(dir, patterns)
    local out = {}
    if fs.getInfo(dir) then
        for _, name in ipairs(fs.getDirectoryItems(dir)) do
            local n = name:lower()
            for _, p in ipairs(patterns) do
                if n:match(p) then out[#out + 1] = name break end
            end
        end
    end
    table.sort(out)
    return out
end

local function getConfig()
    local ok, config = pcall(require, ROOT .. ".config")
    return ok and type(config) == "table" and config or {}
end

local warned = 0
local function warn(fmt, ...)
    warned = warned + 1
    debuglog.warn(fmt, ...)
end

-- ------------------------------------------------------------------
-- the checks
-- ------------------------------------------------------------------
local function checkBackground(config)
    local spec = config.menuBackground
    if spec == nil then return end
    if type(spec) ~= "table" or not spec.image then
        return warn("config.menuBackground needs an image, e.g. { image = \"%s/background/my_image.png\", blur = 8, dim = 0.3 } (it is ignored until it has one)", DIR)
    end

    local path = spec.image
    if not exists(path) then
        local have = listFiles(DIR .. "/background", { "%.png$", "%.jpe?g$" })
        local hint = #have > 0 and (" Images in %s/background/: " .. table.concat(have, ", ") .. ".")
            or (" There are no images in %s/background/ yet -- drop a .png or .jpg there.")
        return warn("menu background image not found: \"%s\" -- the path is from the game root, so it should look like \"%s/background/<file>\"." .. hint,
            path, DIR, DIR)
    end

    local ok, err = pcall(love.image.newImageData, path)
    if not ok then
        warn("menu background image \"%s\" exists but could not be read (corrupt or unsupported format?): %s", path, tostring(err))
    end

    if spec.blur ~= nil and (type(spec.blur) ~= "number" or spec.blur < 0 or spec.blur > 10) then
        warn("menuBackground.blur = %s is outside 0..10 (it will be clamped)", tostring(spec.blur))
    end
    if spec.dim ~= nil and (type(spec.dim) ~= "number" or spec.dim < 0 or spec.dim > 1) then
        warn("menuBackground.dim = %s is outside 0..1 (0 = no dim, 1 = solid black)", tostring(spec.dim))
    end
end

local function checkFonts(config)
    local dir = DIR .. "/fonts"
    if not exists(dir) then
        return warn("fonts folder not found (%s/) -- using LOVE's built-in font, so the menus will not look like the template. Create it and drop a .ttf or .otf inside.", dir)
    end

    local found = listFiles(dir, { "%.ttf$", "%.otf$" })
    if #found == 0 then
        return warn("no .ttf or .otf font files in %s/ -- using LOVE's built-in font, so the menus will not look like the template. Drop any .ttf / .otf in there (any file name).", dir)
    end

    if config.font and not isFile(dir .. "/" .. config.font) then
        warn("config.font = \"%s\" is not in %s/ -- falling back to \"%s\". Files there: %s",
            config.font, dir, found[1], table.concat(found, ", "))
    elseif #found > 1 and not config.font then
        debuglog.log("fonts: %d fonts in %s/, using \"%s\" (the first, alphabetically). Set config.font = \"<file name>\" to choose.",
            #found, dir, found[1])
    end
end

local function checkFilters()
    local okm, crt = pcall(require, ROOT .. ".crt_manager")
    if not okm or not crt.getOptions then return end
    local dir = DIR .. "/crt_filters"

    local registered, missing, present = {}, {}, 0
    for _, def in ipairs(crt.getOptions()) do
        if def.module then
            local file = (def.module:gsub("%.", "/")) .. ".lua"          -- "crt_filters/crt_filter.lua"
            registered[file:match("[^/]+$"):lower()] = true
            if isFile(DIR .. "/" .. file) then present = present + 1
            else missing[#missing + 1] = file end
        end
    end

    if not exists(dir) or #listFiles(dir, { "%.lua$" }) == 0 then
        return warn("no screen-filter (CRT) files in %s/ -- Settings -> Textures can only be set to OFF. Restore the crt_filter*.lua files, or ignore this if you do not want screen filters.", dir)
    end

    if present == 0 then
        return warn("none of the screen filters listed in crt_manager.lua exist in %s/ (looked for: %s) -- Settings -> Textures can only be set to OFF.",
            dir, table.concat(missing, ", "))
    end
    for _, file in ipairs(missing) do
        warn("screen filter file missing: %s/%s (listed in crt_manager.lua) -- it will show as unavailable in Settings -> Textures.", DIR, file)
    end

    -- the other direction: a filter file nobody registered
    for _, name in ipairs(listFiles(dir, { "%.lua$" })) do
        if not registered[name:lower()] then
            warn("%s/%s is not listed in crt_manager.lua's `defs`, so it will not appear in the menu. Add one line there to use it.", dir, name)
        end
    end
end

local function checkIntroVideos(config)
    local list = config.introVideos
    if type(list) ~= "table" then return end
    for _, path in ipairs(list) do
        if not isFile(path) then
            warn("intro video not found: \"%s\" (config.introVideos) -- it will be skipped.", tostring(path))
        elseif not tostring(path):lower():match("%.ogv$") then
            warn("intro video \"%s\" is not .ogv -- LOVE 11 only plays Ogg Theora video, so this will fail to load.", path)
        end
    end
end

local function checkSounds()
    local sounds = require(ROOT .. ".ui_sounds")
    local audio = require(ROOT .. ".audio")
    local dir = DIR .. "/sounds"

    -- the file that is actually in use must decode (audio.lua warns with the path if not)
    for _, slot in ipairs({ "ui", "loading" }) do
        local path = sounds.path(slot)
        if path then audio.getSFXDuration(path) end
    end

    -- a file named like a slot but with an extension that is never looked for
    for _, name in ipairs(listFiles(dir, { "^ui%.[^.]+$", "^loading%.[^.]+$" })) do
        local ext = name:lower():match("%.([^.]+)$")
        if ext ~= "ogg" and ext ~= "mp3" and ext ~= "wav" then
            warn("%s/%s is ignored: only .ogg, .mp3 and .wav are used. Convert it, e.g. to %s.ogg.",
                dir, name, (name:gsub("%.[^.]+$", "")))
        end
    end
end

local function checkSaveFolder()
    local name = "ultimate_ui_write_test.tmp"
    local ok, err = fs.write(name, "ok")
    if ok then
        fs.remove(name)
    else
        warn("cannot write to the save folder (%s): settings, keybinds and filter choices will not persist. %s",
            fs.getSaveDirectory(), tostring(err or ""))
    end
end

local function checkLoveVersion()
    local major, minor = love.getVersion()
    if major ~= 11 then
        warn("this template targets LOVE 11.x, but this is LOVE %d.%d -- some APIs may differ.", major, minor)
    end
end

local function checkSandboxShipped()
    if fs.isFused() and exists(DIR .. "/sandbox/init.lua") then
        warn("%s/sandbox/ is still in this packaged build -- delete that folder before you ship (it is a dev tool).", DIR)
    end
end

-- ------------------------------------------------------------------
-- public
-- ------------------------------------------------------------------
local ALL = {
    { "menu background", checkBackground },
    { "fonts",           checkFonts },
    { "screen filters",  checkFilters },
    { "intro videos",    checkIntroVideos },
    { "sounds",          checkSounds },
    { "save folder",     checkSaveFolder },
    { "LOVE version",    checkLoveVersion },
    { "sandbox",         checkSandboxShipped },
}

-- Runs every check, prints findings, returns the number of warnings.
-- Safe to call again (e.g. after you change config at runtime).
function checks.run()
    local config = getConfig()
    if config.startupChecks == false then return 0 end

    warned = 0
    for _, entry in ipairs(ALL) do
        local ok, err = pcall(entry[2], config)
        if not ok then
            warn("startup check '%s' could not run: %s", entry[1], tostring(err))
        end
    end

    if warned == 0 then
        debuglog.log("startup checks: all OK")
    else
        debuglog.log("startup checks: %d warning(s) -- see the WARNING lines above", warned)
    end
    return warned
end

return checks
