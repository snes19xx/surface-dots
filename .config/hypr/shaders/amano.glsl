#version 320 es
/*
    Yoshitaka Amano Style Shader
    
    Key characteristics being simulated:
      - Hard ink crush in shadows (deep violet-black)
      - Blown-out, slightly warm highlights
      - Selective saturation boost for warm hues (red/gold)
      - Watercolor-like grain in shadows/midtones, clean in highlights
      - Subtle desaturation in upper-midtones to simulate diffuse wash before highlights
    
    Single-pixel sample; safe for Hyprland damage tracking.

    by @snes19xx, https://github.com/snes19xx
*/
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// --- Palette ---
// Amano's ink is not pure black; it's slightly warm violet-indigo.
const vec3 INK_COLOR     = vec3(0.04, 0.03, 0.10);
const vec3 PAPER_COLOR   = vec3(0.97, 0.94, 0.86);
const vec3 WASH_COLOR    = vec3(0.55, 0.58, 0.68);

// --- Noise ---
// A fast, low-bias hash for grain texture.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// --- Saturation helper ---
vec3 adjustSaturation(vec3 col, float sat) {
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    return mix(vec3(lum), col, sat);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color    = pixColor.rgb;

    float luma = dot(color, vec3(0.299, 0.587, 0.114));

    // -------------------------------------------------------------------------
    // HARD INK CONTRAST
    // -------------------------------------------------------------------------
    // A three-zone remap:
    //   0.00 - 0.25 --> shadow zone: pushed hard toward INK_COLOR
    //   0.25 - 0.65 --> wash zone:   the subtle blue-grey midtone
    //   0.65 - 1.00 --> highlight:   rapid bloom to PAPER_COLOR
    //
    // build this as two smoothsteps composited together.
    float shadowT    = smoothstep(0.0,  0.28, luma); 
    float highlightT = smoothstep(0.52, 1.0,  luma);  

    // Blend ink --> wash --> paper
    vec3 toned = mix(INK_COLOR, WASH_COLOR, shadowT);
    toned      = mix(toned, PAPER_COLOR, highlightT);

    // -------------------------------------------------------------------------
    // WARM COLOR ISOLATION WITH SATURATION BOOST
    // -------------------------------------------------------------------------

    // "Warmness" = how much red dominates over the cooler channels.
    float warmness = max(0.0, color.r - max(color.g * 0.9, color.b));
    // "Goldness" for high-luma warm regions.
    float goldness = max(0.0, (color.r + color.g * 0.5) * 0.5 - color.b * 1.2);
    float heat     = clamp(max(warmness, goldness) * 2.2, 0.0, 1.0);

    // In warm zones, boost the original color's saturation to ~~1.6x
    // then blend it into the toned result.
    vec3 boostedWarm = adjustSaturation(color, 1.6);
    // The blend weight is heat-driven but also requires some base presence
    // (a very dark red, like a shadow, should still mostly be ink).
    float warmBlend = heat * smoothstep(0.08, 0.5, luma);
    warmBlend       = clamp(warmBlend, 0.0, 0.85);

    vec3 result = mix(toned, boostedWarm, warmBlend);

    // -------------------------------------------------------------------------
    // UPPER-MIDTONE DESATURATION  (for wash effect)
    // -------------------------------------------------------------------------

    float washZone   = smoothstep(0.45, 0.72, luma) * (1.0 - highlightT);
    float washAmount = washZone * (1.0 - warmBlend);
    result = adjustSaturation(result, 1.0 - washAmount * 0.7);

    // -------------------------------------------------------------------------
    // PAPER GRAIN -- more coarser in shadows, absent in highlights
    // -------------------------------------------------------------------------
    float n1 = hash(gl_FragCoord.xy * 0.37);
    float n2 = hash(gl_FragCoord.xy * 0.71 + 17.3);
    float grain = (n1 * 0.65 + n2 * 0.35 - 0.5);

    // Grain mask
    float grainMask = smoothstep(0.0, 0.35, luma) * (1.0 - smoothstep(0.55, 0.85, luma));
    result += grain * grainMask * 0.075;

    // -------------------------------------------------------------------------
    // FINAL TONE 
    // -------------------------------------------------------------------------
    float shadowLift = (1.0 - smoothstep(0.0, 0.2, luma)) * 0.03;
    result += shadowLift * PAPER_COLOR;

    fragColor = vec4(clamp(result, 0.0, 1.0), pixColor.a);
}