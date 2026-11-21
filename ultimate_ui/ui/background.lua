-- ui/background.lua
-- Full-screen background layer with optional heavy blur, drawn behind a
-- widget screen. Handy for judging how text and buttons read over game art.
--
--   background.draw({ image = "ultimate_ui/background/your_image.png", blur = 8 }, screenW, screenH)
--
--   image  path to an image (png/jpg), from the game root -- scaled to COVER the screen, centered
--   blur   0 = sharp, 1..10 = increasingly strong (8 is "blur like crazy")
--
-- Blurring is done once and cached (re-done only when the window size, image
-- or blur level changes): the image is shrunk to a tiny canvas, softened with a
-- two-pass gaussian shader, then stretched back up with linear filtering. If
-- the shader can't compile, shrink-and-stretch alone still gives a soft blur.
-- A missing image is skipped (one console warning), never fatal.

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")
local background = {}

local MAX_BLUR = 10
background.MAX_BLUR = MAX_BLUR

local images = {}        -- path -> image | false (failed)
local cache = nil        -- { key =, canvas = }
local shader, shaderTried = nil, false
local warned = {}

local SHADER = [[
extern vec2 dir;   // one-texel step along the blur axis
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 sum = Texel(tex, uv) * 0.2270270270;
    sum += Texel(tex, uv + dir * 1.3846153846) * 0.3162162162;
    sum += Texel(tex, uv - dir * 1.3846153846) * 0.3162162162;
    sum += Texel(tex, uv + dir * 3.2307692308) * 0.0702702703;
    sum += Texel(tex, uv - dir * 3.2307692308) * 0.0702702703;
    return sum * color;
}
]]

local function getShader()
    if not shaderTried then
        shaderTried = true
        local ok, s = pcall(love.graphics.newShader, SHADER)
        shader = ok and s or nil
    end
    return shader
end

local function warn(path, msg)
    if not warned[path] then
        warned[path] = true
        print("[background] " .. path .. ": " .. tostring(msg))
    end
end

local function getImage(path, sharp)
    local img = images[path]
    if img == nil then
        local ok, result
        local tfm_ok, tfm = pcall(require, ROOT .. ".texture_filter_manager")
        if tfm_ok and tfm.newImage then ok, result = pcall(tfm.newImage, path)
        else ok, result = pcall(love.graphics.newImage, path) end
        if ok then img = result else img = false warn(path, result) end
        images[path] = img
    end
    return img or nil
end

-- Scale + offset that make an iw x ih image cover w x h, centered.
local function coverTransform(iw, ih, w, h)
    local s = math.max(w / iw, h / ih)
    return s, (w - iw * s) / 2, (h - ih * s) / 2
end
background._cover = coverTransform

local function build(img, blur, w, h)
    local iw, ih = img:getDimensions()
    local d = 1 + blur * 1.5                          -- shrink factor
    local lw, lh = math.max(2, math.ceil(w / d)), math.max(2, math.ceil(h / d))

    local a = love.graphics.newCanvas(lw, lh)
    local b = love.graphics.newCanvas(lw, lh)
    a:setFilter("linear", "linear")
    b:setFilter("linear", "linear")

    local prevCanvas = love.graphics.getCanvas()
    local r, g, bl, al = love.graphics.getColor()
    love.graphics.push("all")
    love.graphics.origin()

    -- 1. shrink the image into `a` (image goes in with linear filtering so the
    --    big downscale averages instead of skipping pixels)
    local oldMin, oldMag = img:getFilter()
    img:setFilter("linear", "linear")
    love.graphics.setCanvas(a)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    local s, ox, oy = coverTransform(iw, ih, lw, lh)
    love.graphics.draw(img, ox, oy, 0, s, s)
    img:setFilter(oldMin, oldMag)

    -- 2. gaussian blur, a few ping-pong passes at the small size
    local sh = getShader()
    if sh then
        love.graphics.setShader(sh)
        local src, dst = a, b
        for _ = 1, 3 do
            sh:send("dir", { 1 / lw, 0 })
            love.graphics.setCanvas(dst) love.graphics.clear(0, 0, 0, 1)
            love.graphics.draw(src)
            src, dst = dst, src
            sh:send("dir", { 0, 1 / lh })
            love.graphics.setCanvas(dst) love.graphics.clear(0, 0, 0, 1)
            love.graphics.draw(src)
            src, dst = dst, src
        end
        love.graphics.setShader()
        a = src
    end

    love.graphics.pop()
    love.graphics.setCanvas(prevCanvas)
    love.graphics.setColor(r, g, bl, al)
    return a
end

-- Draws the background. `spec` = { image =, blur = }; nil/empty spec draws nothing.
function background.draw(spec, w, h)
    if not spec or not spec.image then return end
    local img = getImage(spec.image)
    if not img then return end
    local blur = math.max(0, math.min(MAX_BLUR, spec.blur or 0))

    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    if blur == 0 then
        local iw, ih = img:getDimensions()
        local s, ox, oy = coverTransform(iw, ih, w, h)
        love.graphics.draw(img, ox, oy, 0, s, s)
    else
        local key = table.concat({ spec.image, blur, w, h }, "|")
        if not cache or cache.key ~= key then
            local ok, canvas = pcall(build, img, blur, w, h)
            if not ok then warn(spec.image, canvas) love.graphics.pop() return end
            cache = { key = key, canvas = canvas }
        end
        local cw, ch = cache.canvas:getDimensions()
        love.graphics.draw(cache.canvas, 0, 0, 0, w / cw, h / ch)
    end
    love.graphics.pop()
end

-- The ONE background every menu page shares (main, pause, settings, keyboard,
-- controller, other, texture, loading). Lives in config.lua as
--   config.menuBackground = { image = "ultimate_ui/background/x.png", blur = 8, dim = 0.3 }
-- (nil = no background: pages keep their plain dark overlay). `dim` is the black
-- overlay alpha used over the picture on every page, so they all look alike.
function background.shared()
    local ok, config = pcall(require, ROOT .. ".config")
    local spec = ok and config.menuBackground or nil
    if spec and spec.image then return spec end
    return nil
end

-- Sets (or, with nil, clears) the shared menu background at runtime.
function background.setShared(spec)
    local config = require(ROOT .. ".config")
    config.menuBackground = spec and spec.image and
        { image = spec.image, blur = spec.blur, dim = spec.dim } or nil
end

-- Image files available in this library's background/ folder (sorted), for the editor
-- to cycle through. Paths are returned from the game root.
function background.list(dir)
    dir = dir or ((ROOT:gsub("%.", "/")) .. "/background")
    local out = {}
    if love.filesystem.getInfo(dir) then
        for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
            if name:lower():match("%.png$") or name:lower():match("%.jpe?g$") then
                out[#out + 1] = dir .. "/" .. name
            end
        end
    end
    table.sort(out)
    return out
end

return background
