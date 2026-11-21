-- crt_filter2.lua  --  "NEON ARCADE"
-- A bright, glowing arcade-monitor look, deliberately the opposite of the
-- classic filter: no green tint, no VHS wobble. Instead:
--   * Bloom: bright pixels bleed light into their neighbours (2 blur rings)
--   * RGB aperture-grille phosphor mask (vertical R/G/B stripes)
--   * Beam scanlines that fade out on bright pixels, like a real CRT beam
--   * Rounded screen corners, soft vignette, gentle curvature
--   * Slow rolling brightness band + faint power flicker
--   * Saturation boost for that vivid cabinet look
-- All tunables are exposed through M.settings (Settings -> CRT Filters).
local M = {}

local shaderCode = [[
extern number time;
extern vec2 resolution;
extern number curve;
extern number glow;
extern number maskStrength;
extern number beamStrength;
extern number flicker;
extern number saturation;

// CENTER FIT: how much of the curve's built-in zoom to keep.
//   1.0 = original look: corners pinned exactly, no cropping, but the middle of
//         the picture is magnified by (1 + curve), which pushes content away
//         from the screen center (a menu sitting above center gets "kicked up").
//   lower = less zoom / less push, at the cost of the last few % of the far
//         corners falling off the picture (they fade to black, like a real
//         curved tube's bezel). 0.8 = ~20% less push, ~2-3% corner trim.
const float CENTER_FIT = 0.8;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Scale pixel-sized effects with resolution (1x at 1080p, 2x at 4K)
    float s = max(1.0, floor(resolution.y / 1080.0 + 0.5));

    // Screen-space position in [-1, 1]
    vec2 p = texture_coords * 2.0 - 1.0;

    // --- Rounded screen corners ---
    vec2 d = abs(p) - vec2(1.0 - 0.06);
    float sd = length(max(d, vec2(0.0))) - 0.06;
    float screenMask = 1.0 - smoothstep(-0.004, 0.0, sd);

    // --- Gentle barrel curvature (see CENTER_FIT above) ---
    vec2 w = p;
    w += w * (w.yx * w.yx) * curve;
    w /= (1.0 + curve * CENTER_FIT);
    vec2 uv = w * 0.5 + 0.5;

    // With CENTER_FIT < 1 the extreme corners sample just past the canvas:
    // fade those to black instead of smearing the edge pixels.
    vec2 inb = smoothstep(vec2(0.0), vec2(0.004), uv) * (1.0 - smoothstep(vec2(0.996), vec2(1.0), uv));
    screenMask *= inb.x * inb.y;

    vec4 base = Texel(texture, uv);
    vec3 col = base.rgb;

    // --- Bloom: two rings of 8 taps, thresholded so only bright stuff glows ---
    vec2 px = 1.0 / resolution;
    vec3 ring1 = vec3(0.0);
    vec3 ring2 = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        float ang = float(i) * 0.785398;
        vec2 dir = vec2(cos(ang), sin(ang));
        ring1 += Texel(texture, uv + dir * px * 3.0 * s).rgb;
        ring2 += Texel(texture, uv + dir * px * 9.0 * s).rgb;
    }
    vec3 blur = (ring1 * 0.6 + ring2 * 0.4) / 8.0;
    col += max(blur - vec3(0.12), vec3(0.0)) * glow * 1.6;

    // --- Saturation ---
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, saturation);

    // --- Beam scanlines (bright pixels "bloom" the beam wider, so lines fade) ---
    float pitch = 3.0 * s;
    float beam = 0.5 + 0.5 * cos(6.28318 * screen_coords.y / pitch);
    float lineMod = mix(1.0 - beamStrength, 1.0, beam);
    lineMod = mix(lineMod, 1.0, clamp(lum, 0.0, 1.0) * 0.5);
    col *= lineMod;

    // --- Aperture grille: repeating R / G / B vertical stripes ---
    float ch = mod(floor(screen_coords.x / s), 3.0);
    vec3 m = vec3(1.0 - step(0.5, ch),
                  step(0.5, ch) * (1.0 - step(1.5, ch)),
                  step(1.5, ch));
    col *= (1.0 - maskStrength) + maskStrength * m * 1.5;
    col *= 1.0 + maskStrength * 0.3; // brightness make-up for the mask

    // --- Rolling brightness band + faint flicker ---
    float roll = 1.0 + flicker * (0.7 * sin(time * 1.6 - p.y * 3.0)
                                + 0.3 * sin(time * 47.0));
    col *= roll;

    // --- Soft vignette ---
    col *= 1.0 - 0.1 * dot(p, p);

    return vec4(col, base.a) * screenMask * color;
}
]]

function M.init()
    M.shader = love.graphics.newShader(shaderCode)
    M.time = 0
    -- Defaults (keep in sync with the defaultIndex of each setting below)
    M.curve = 0.1
    M.glow = 0.5
    M.maskStrength = 0.35
    M.beamStrength = 0.3
    M.flicker = 0.01
    M.saturation = 1.25
end

function M.update(dt)
    M.time = M.time + dt
end

function M.apply()
    if not M.shader then return end
    M.shader:send("time", M.time)
    M.shader:send("resolution", { love.graphics.getWidth(), love.graphics.getHeight() })
    M.shader:send("curve", M.curve)
    M.shader:send("glow", M.glow)
    M.shader:send("maskStrength", M.maskStrength)
    M.shader:send("beamStrength", M.beamStrength)
    M.shader:send("flicker", M.flicker)
    M.shader:send("saturation", M.saturation)
    love.graphics.setShader(M.shader)
end

function M.endApply()
    love.graphics.setShader()
end

M.settings = {
    { id = "glow", label = "GLOW", defaultIndex = 3,
      apply = function(v) M.glow = v end,
      options = {
          { label = "OFF",     value = 0 },
          { label = "SOFT",    value = 0.25 },
          { label = "NORMAL",  value = 0.5 },
          { label = "INTENSE", value = 0.9 },
      } },
    { id = "mask", label = "PHOSPHOR MASK", defaultIndex = 3,
      apply = function(v) M.maskStrength = v end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LIGHT",  value = 0.2 },
          { label = "NORMAL", value = 0.35 },
          { label = "HEAVY",  value = 0.5 },
      } },
    { id = "beam", label = "SCANLINE BEAM", defaultIndex = 3,
      apply = function(v) M.beamStrength = v end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.15 },
          { label = "NORMAL", value = 0.3 },
          { label = "HIGH",   value = 0.5 },
      } },
    { id = "curve", label = "SCREEN CURVE", defaultIndex = 3,
      apply = function(v) M.curve = v end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.05 },
          { label = "NORMAL", value = 0.1 },
          { label = "HIGH",   value = 0.18 },
      } },
    { id = "flicker", label = "FLICKER", defaultIndex = 2,
      apply = function(v) M.flicker = v end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.01 },
          { label = "NORMAL", value = 0.02 },
          { label = "HIGH",   value = 0.04 },
      } },
    { id = "saturation", label = "COLOR", defaultIndex = 3,
      apply = function(v) M.saturation = v end,
      options = {
          { label = "MUTED",  value = 0.8 },
          { label = "NORMAL", value = 1.0 },
          { label = "VIVID",  value = 1.25 },
          { label = "POP",    value = 1.5 },
      } },
}

return M
