#version 320 es

/*
    Matte / Anti-Glare display simulation.
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float CONTRAST   = 1.08;
const float VIBRANCE   = 0.10;
const float SATURATION = 1.03;

const float WARM_STR   = 0.15;          // 0.0 = off, 0.30 = evening warmth
const vec3  WARM_TINT  = vec3(1.0, 0.93, 0.85);

const float GRAIN_STR  = 0.055;
const float BLACK_LIFT = 0.04;          // Additive shadow floor, not gray mix

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color    = pixColor.rgb;

    // Contrast
    color = (color - 0.5) * CONTRAST + 0.5;

    // Vibrance (skin-protected)
    float luma     = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float sat      = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
    float skinMask = smoothstep(0.3, 0.6, color.r) * smoothstep(0.6, 0.3, color.g) * 0.5;
    color = mix(vec3(luma), color, 1.0 + VIBRANCE * (1.0 - sat) * (1.0 - skinMask));

    // Saturation
    luma  = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, SATURATION);

    // Warmth — only applied to bright pixels, leaves shadows neutral
    luma  = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float warmMask = pow(luma, 0.6);
    color = mix(color, color * WARM_TINT, warmMask * WARM_STR);

    // Matte grain
    color += (hash(gl_FragCoord.xy) - 0.5) * GRAIN_STR;

    // Shadow lift — additive, masked to dark pixels only
    luma  = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color += (1.0 - smoothstep(0.0, 0.3, luma)) * BLACK_LIFT;

    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}