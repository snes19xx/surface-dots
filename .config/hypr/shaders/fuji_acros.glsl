#version 320 es

/*
    Fujifilm Acros film simulation. [MONOCHROME]
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float GREEN_FILTER = 0.0;  // 0.0 = standard, 1.0
const float RED_FILTER   = 0.0;  // 0.0 = standard, 1.0
const float GRAIN_SIZE   = 1.0;  // Grain scale. 1.0 = box64 equivalent.

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float acrosCurve(float t) {
    t = max(t - 0.04, 0.0) / 0.96;

    // Core S-curve
    float toe = smoothstep(0.0, 0.35, t);
    float mid = smoothstep(0.2, 0.8, t);
    float shoulder = smoothstep(0.65, 1.0, t);

    return mix(toe * 0.6, mix(mid * 0.85, t, shoulder * 0.4), 0.5);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 rgb = pixColor.rgb;

    vec3 weights = vec3(0.18, 0.74, 0.08);

    weights.g += GREEN_FILTER * 0.12;
    weights.r -= GREEN_FILTER * 0.06;

    weights.r += RED_FILTER * 0.14;
    weights.b -= RED_FILTER * 0.08;

    float wSum = weights.r + weights.g + weights.b;
    weights /= wSum;

    float luma = dot(rgb, weights);
    luma = acrosCurve(luma);

    // Acros grain: fine and slightly clumped in midtones
    float midtoneMask = smoothstep(0.2, 0.5, luma) * (1.0 - smoothstep(0.5, 0.8, luma));
    float grainCoarse = (hash(floor(gl_FragCoord.xy / GRAIN_SIZE) * 0.5) - 0.5);
    float grainFine   = (hash(gl_FragCoord.xy * 1.3) - 0.5) * 0.4;
    float grain = (grainCoarse + grainFine) * 0.022;

    // More grain in midtones, less in deep blacks and bright whites
    luma += grain * (0.4 + midtoneMask * 0.6);

    luma = clamp(luma, 0.0, 1.0);

    // Output is true monochrome 
    fragColor = vec4(vec3(luma), pixColor.a);
}