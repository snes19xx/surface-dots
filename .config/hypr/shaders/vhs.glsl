#version 320 es

/*
    [NOTE] True chroma shift needs textureOffset, which breaks damage tracking.
    This is my approximation of textureOffset which is damage-tracking safe.

    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float NOISE      = 0.055;
const float WARP       = 0.012;  // Tape tracking warp amplitude
const float SATURATION = 1.18;   // NTSC chroma push

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    // Tape warp: horizontal luminance shift using sine on Y
    float warpBand = sin(v_texcoord.y * 480.0) * WARP;
    color.rgb += warpBand;

    // NTSC chroma noise:
    color.g += hash(gl_FragCoord.xy * 0.25) * 0.03 - 0.015;

    // Saturation push for that oversaturated VHS color
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, SATURATION);

    // Static noise, heavier near the top and bottom edges
    float edgeDamage = smoothstep(0.08, 0.0, v_texcoord.y) + smoothstep(0.92, 1.0, v_texcoord.y);
    float noise = (hash(gl_FragCoord.xy) - 0.5) * (NOISE + edgeDamage * 0.2);
    color += noise;

    // Horizontal scanline bands (tape format had ~240 lines apparently)
    float scanline = sin(gl_FragCoord.y * 3.14159) * 0.5 + 0.5;
    color *= mix(0.92, 1.0, scanline);

    // Soft vignette
    vec2 uv = v_texcoord - 0.5;
    float vig = 1.0 - smoothstep(0.45, 1.1, length(uv)) * 0.35;
    color *= vig;

    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}