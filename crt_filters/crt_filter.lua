-- crt_filter.lua
local crt_filter = {}

-- Combined CRT shader: Barrel Distortion + Vignette + Scanlines + Green Tint + Chromatic Aberration + VHS Tracking
local crt_shader_code = [[
extern number time;
extern vec2 resolution;
extern vec2 distortionFactor;
extern vec2 scaleFactor;
extern number feather;
extern number aberrationAmount;
extern number vhsRippleStrength;
extern number vhsRippleSpeed;
extern number scanlineStrength;
extern number vignetteStrength;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // --- Barrel Distortion ---
    vec2 uv = texture_coords * 2.0 - vec2(1.0);
    uv *= scaleFactor;
    uv += (uv.yx * uv.yx) * uv * (distortionFactor - 1.0);
    
    // Feather mask to smoothly fade out the distorted edges to transparent
    float mask = (1.0 - smoothstep(1.0 - feather, 1.0, abs(uv.x)))
               * (1.0 - smoothstep(1.0 - feather, 1.0, abs(uv.y)));
               
    uv = (uv + vec2(1.0)) / 2.0;

    // --- VHS Tracking Ripple (Tuned for discrete, smooth artifacts) ---
    // Slower traveling wave down the screen
    float waveY = mod(time * vhsRippleSpeed, 2.5) - 0.5; 
    float distToWave = abs(uv.y - waveY);
    
    // Softer, wider Gaussian band (reduced from 25.0 to 12.0 for less harsh edges)
    float vhsBand = exp(-pow(distToWave * 12.0, 2.0));
    
    // Lower-frequency, smoother wobble (reduced from 100.0 to 35.0)
    float wobble = sin(uv.y * 35.0 + time * 8.0) * vhsRippleStrength;
    float vhsShift = wobble * vhsBand;
    
    // Apply the shift to the base UV coordinates
    uv.x += vhsShift;

    // --- Chromatic Aberration ---
    // Shift the red and blue channels slightly. The color bleed respects the smooth tracking error.
    float r = Texel(texture, uv - vec2(aberrationAmount + vhsShift * 0.5, 0.0)).r;
    float g = Texel(texture, uv).g;
    float b = Texel(texture, uv + vec2(aberrationAmount + vhsShift * 0.5, 0.0)).b;
    float a = Texel(texture, uv).a;

    vec4 texcolor = color * vec4(r, g, b, a) * mask;

    // --- Vignette (darker edges) ---
    vec2 coord = screen_coords / resolution;
    float dist = distance(coord, vec2(0.5, 0.5));
    
    // Strength now comes from Settings -> CRT Filters (default 0.2).
    float vignette = 1.0 - dist * vignetteStrength; 

    // --- Moving Scanlines ---
    float scanlinePos = mod(screen_coords.y + time * 500.0, 30.0);
    float scanline = smoothstep(0.0, 2.0, scanlinePos) * smoothstep(2.0, 0.0, scanlinePos - 2.0);

    // --- Light Green Tint Adjustment ---
    float final_r = texcolor.r * 0.9 + texcolor.g * 0.3 + texcolor.b * 0.2;
    float final_g = texcolor.g * 1.0 + texcolor.r * 0.1 + texcolor.b * 0.1;
    float final_b = texcolor.b * 0.8 + texcolor.r * 0.3 + texcolor.g * 0.2;

    // --- Combine Effects ---
    
    // CHANGE 2: Added a global brightness multiplier. 
    // 1.0 is normal brightness. Try 1.2 for 20% brighter, or 1.3 for 30% brighter.
    float brightnessBoost = 1.00; 

    // CHANGE 3: Changed the base multiplier from 0.9 to 1.0. 
    // Your original code was setting the base screen brightness to 90% (0.9).
    return vec4(final_r, final_g, final_b, texcolor.a) * brightnessBoost * vignette * (1.0 + scanline * scanlineStrength);
}
]]

function crt_filter.init()
    crt_filter.shader = love.graphics.newShader(crt_shader_code)
    crt_filter.enabled = true
    crt_filter.time = 0
    
    -- Default values for the barrel distortion
    crt_filter.distortionFactor = {1.18, 1.18}
    crt_filter.scaleFactor = {0.95, 0.95}
    crt_filter.feather = 0.02

    -- Default value for chromatic aberration
    crt_filter.aberrationAmount = 0.001

    -- NEW: VHS Tracking Ripple settings (Tuned for subtlety)
    crt_filter.vhsRippleStrength = 0.003 -- Lowered for a gentler shift
    crt_filter.vhsRippleSpeed = 0.3      -- Ripple speed

    -- Previously hardcoded in the shader
    crt_filter.scanlineStrength = 0.07
    crt_filter.vignetteStrength = 0.2
end

function crt_filter.enable()
    crt_filter.enabled = true
end

function crt_filter.disable()
    crt_filter.enabled = false
end

function crt_filter.toggle()
    crt_filter.enabled = not crt_filter.enabled
end

function crt_filter.setDistortionFactor(v)
    if type(v) == "table" and #v == 2 then
        crt_filter.distortionFactor = {v[1], v[2]}
    elseif type(v) == "number" then
        crt_filter.distortionFactor = {v, v}
    end
end

function crt_filter.setScaleFactor(v)
    if type(v) == "table" and #v == 2 then
        crt_filter.scaleFactor = {v[1], v[2]}
    elseif type(v) == "number" then
        crt_filter.scaleFactor = {v, v}
    end
end

function crt_filter.setFeather(v)
    crt_filter.feather = v
end

function crt_filter.setAberrationAmount(v)
    crt_filter.aberrationAmount = v
end

function crt_filter.setVHSRippleStrength(v)
    crt_filter.vhsRippleStrength = v
end

function crt_filter.setVHSRippleSpeed(v)
    crt_filter.vhsRippleSpeed = v
end

function crt_filter.setScanlineStrength(v)
    crt_filter.scanlineStrength = v
end

function crt_filter.setVignetteStrength(v)
    crt_filter.vignetteStrength = v
end

-- ==========================================
-- SETTINGS CONTRACT (read by crt_manager.lua / ui/crt_filters_menu.lua)
-- Each row cycles through `options`; `apply(value)` pushes the chosen
-- value into this filter. defaultIndex must match the init() defaults
-- above. Choices are saved per-filter by crt_manager.
-- ==========================================
crt_filter.settings = {
    { id = "curvature", label = "SCREEN CURVE", defaultIndex = 3,
      apply = function(v) crt_filter.setDistortionFactor(v) end,
      options = {
          { label = "OFF",    value = 1.0 },
          { label = "LOW",    value = 1.08 },
          { label = "NORMAL", value = 1.18 },
          { label = "HIGH",   value = 1.3 },
      } },
    { id = "scanlines", label = "SCANLINES", defaultIndex = 3,
      apply = function(v) crt_filter.setScanlineStrength(v) end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.035 },
          { label = "NORMAL", value = 0.07 },
          { label = "HIGH",   value = 0.14 },
      } },
    { id = "vignette", label = "VIGNETTE", defaultIndex = 3,
      apply = function(v) crt_filter.setVignetteStrength(v) end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.1 },
          { label = "NORMAL", value = 0.2 },
          { label = "HIGH",   value = 0.4 },
      } },
    { id = "aberration", label = "COLOR FRINGE", defaultIndex = 3,
      apply = function(v) crt_filter.setAberrationAmount(v) end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.0005 },
          { label = "NORMAL", value = 0.001 },
          { label = "HIGH",   value = 0.002 },
      } },
    { id = "vhs", label = "VHS RIPPLE", defaultIndex = 3,
      apply = function(v) crt_filter.setVHSRippleStrength(v) end,
      options = {
          { label = "OFF",    value = 0 },
          { label = "LOW",    value = 0.0015 },
          { label = "NORMAL", value = 0.003 },
          { label = "HIGH",   value = 0.006 },
      } },
}

function crt_filter.update(dt)
    if crt_filter.enabled then
        crt_filter.time = crt_filter.time + dt
    end
end

function crt_filter.apply()
    if not crt_filter.enabled or not crt_filter.shader then
        return
    end
    
    crt_filter.shader:send("time", crt_filter.time)
    crt_filter.shader:send("resolution", {love.graphics.getWidth(), love.graphics.getHeight()})
    crt_filter.shader:send("distortionFactor", crt_filter.distortionFactor)
    crt_filter.shader:send("scaleFactor", crt_filter.scaleFactor)
    crt_filter.shader:send("feather", crt_filter.feather)
    crt_filter.shader:send("aberrationAmount", crt_filter.aberrationAmount)
    crt_filter.shader:send("vhsRippleStrength", crt_filter.vhsRippleStrength)
    crt_filter.shader:send("vhsRippleSpeed", crt_filter.vhsRippleSpeed)
    crt_filter.shader:send("scanlineStrength", crt_filter.scanlineStrength)
    crt_filter.shader:send("vignetteStrength", crt_filter.vignetteStrength)

    love.graphics.setShader(crt_filter.shader)
end

function crt_filter.endApply()
    if crt_filter.enabled then
        love.graphics.setShader()
    end
end

return crt_filter