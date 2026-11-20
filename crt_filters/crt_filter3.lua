-- crt_filter3.lua  --  "HANDHELD LCD"
-- Completely different idea from filters 1 and 2: instead of imitating a
-- tube, this imitates a tiny low-res handheld screen.
--   * Pixelation: the whole frame is snapped to big chunky pixels
--   * 4-shade palette mapping (Game Boy green, amber, ice, mono) with an
--     ordered Bayer dither so gradients become that classic crosshatch
--   * LCD pixel grid: thin dark gaps between pixels
--   * "FULL COLOR" palette keeps your colors but still pixelates + grids
-- Palette mode throws away hue (only brightness survives), so if blocks
-- become hard to tell apart, switch PALETTE to FULL COLOR.
local M = {}

local shaderCode = [[
extern vec2 resolution;
extern number pixelSize;
extern vec3 c0;
extern vec3 c1;
extern vec3 c2;
extern vec3 c3;
extern number paletteMode;   // 1 = 4-shade palette, 0 = keep original color
extern number ditherAmount;
extern number gridStrength;
extern number brightness;

// 2x2 Bayer cell value 0..3 for x,y in {0,1}
float m2(float x, float y) { return mod(2.0 * x + 3.0 * y, 4.0); }

// 4x4 ordered-dither threshold in [0,1), built from two 2x2 levels
float bayer4(vec2 cell) {
    vec2 q = mod(floor(cell), 4.0);
    float a = mod(q.x, 2.0);
    float b = mod(q.y, 2.0);
    float c = floor(q.x / 2.0);
    float d = floor(q.y / 2.0);
    return (4.0 * m2(a, b) + m2(c, d)) / 16.0;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // --- Snap to a coarse pixel grid ---
    vec2 cell = vec2(pixelSize) / resolution;
    vec2 cellIdx = floor(texture_coords / cell);
    vec2 uv = (cellIdx + 0.5) * cell;
    vec4 src = Texel(texture, uv);

    // --- Luminance -> dithered 4-level palette ---
    float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    lum = pow(clamp(lum, 0.0, 1.0), 0.75); // lift darks so the UI stays readable
    float v = clamp(lum + (bayer4(cellIdx) - 0.46875) * ditherAmount, 0.0, 0.9999);
    float idx = floor(v * 4.0);

    vec3 pal = c0;
    pal = mix(pal, c1, step(1.0, idx));
    pal = mix(pal, c2, step(2.0, idx));
    pal = mix(pal, c3, step(3.0, idx));

    vec3 col = mix(src.rgb, pal, paletteMode);

    // --- LCD pixel grid (1 screen-pixel gap on two edges of every cell) ---
    vec2 f = fract(texture_coords / cell);
    float gap = 1.0 / max(pixelSize, 1.0);
    float line = max(step(f.x, gap), step(f.y, gap));
    float gridOn = step(1.5, pixelSize); // no grid when pixelation is off
    col *= 1.0 - gridStrength * line * gridOn;

    col *= brightness;
    return vec4(col, src.a) * color;
}
]]

-- 0xRRGGBB -> {r, g, b} in 0..1
local function rgb(hex)
    return { math.floor(hex / 65536) % 256 / 255,
             math.floor(hex / 256) % 256 / 255,
             hex % 256 / 255 }
end

local PALETTES = {
    gameboy = { mode = 1, pal = { rgb(0x0f380f), rgb(0x306230), rgb(0x8bac0f), rgb(0x9bbc0f) } },
    amber   = { mode = 1, pal = { rgb(0x140a00), rgb(0x5a3200), rgb(0xb86e00), rgb(0xffb000) } },
    ice     = { mode = 1, pal = { rgb(0x0a0f24), rgb(0x27467d), rgb(0x6aa6d9), rgb(0xe6f4ff) } },
    mono    = { mode = 1, pal = { rgb(0x000000), rgb(0x555555), rgb(0xaaaaaa), rgb(0xffffff) } },
    -- Colors unused when mode = 0, but the uniforms still need values.
    full    = { mode = 0, pal = { rgb(0x000000), rgb(0x555555), rgb(0xaaaaaa), rgb(0xffffff) } },
}

function M.init()
    M.shader = love.graphics.newShader(shaderCode)
    -- Defaults (keep in sync with the defaultIndex of each setting below)
    M.pixelSize = 2
    M.palette = PALETTES.gameboy
    M.ditherAmount = 0.12
    M.gridStrength = 0.2
    M.brightness = 1.0
end

function M.update(dt)
    -- Nothing animated; kept so crt_manager can call it uniformly.
end

function M.apply()
    if not M.shader then return end
    local pal = M.palette.pal
    M.shader:send("resolution", { love.graphics.getWidth(), love.graphics.getHeight() })
    M.shader:send("pixelSize", M.pixelSize)
    M.shader:send("c0", pal[1])
    M.shader:send("c1", pal[2])
    M.shader:send("c2", pal[3])
    M.shader:send("c3", pal[4])
    M.shader:send("paletteMode", M.palette.mode)
    M.shader:send("ditherAmount", M.ditherAmount)
    M.shader:send("gridStrength", M.gridStrength)
    M.shader:send("brightness", M.brightness)
    love.graphics.setShader(M.shader)
end

function M.endApply()
    love.graphics.setShader()
end

M.settings = {
    { id = "palette", label = "PALETTE", defaultIndex = 1,
      apply = function(v) M.palette = v end,
      options = {
          { label = "GAME BOY",   value = PALETTES.gameboy },
          { label = "AMBER",      value = PALETTES.amber },
          { label = "ICE",        value = PALETTES.ice },
          { label = "MONO",       value = PALETTES.mono },
          { label = "FULL COLOR", value = PALETTES.full },
      } },
    { id = "pixels", label = "PIXEL SIZE", defaultIndex = 2,
      apply = function(v) M.pixelSize = v end,
      options = {
          { label = "OFF",    value = 1 },
          { label = "FINE",   value = 2 },
          { label = "MEDIUM", value = 4 },
          { label = "CHUNKY", value = 6 },
      } },
    { id = "dither", label = "DITHER", defaultIndex = 2,
      apply = function(v) M.ditherAmount = v end,
      options = {
          { label = "OFF",   value = 0 },
          { label = "LIGHT", value = 0.12 },
          { label = "FULL",  value = 0.25 },
      } },
    { id = "grid", label = "LCD GRID", defaultIndex = 2,
      apply = function(v) M.gridStrength = v end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "SUBTLE", value = 0.2 },
          { label = "STRONG", value = 0.45 },
      } },
    { id = "brightness", label = "BRIGHTNESS", defaultIndex = 2,
      apply = function(v) M.brightness = v end,
      options = {
          { label = "DIM",    value = 0.85 },
          { label = "NORMAL", value = 1.0 },
          { label = "BRIGHT", value = 1.25 },
      } },
}

return M
