#version 320 es
/*
    Simulates 4-bit graphics.
    Uses a 4x4 Bayer matrix to dither luma into a limited palette.
    
    PALETTE_SIZE controls the number of output levels per channel:
      2  = pure 1-bit (black and white Mac look)
      4  = 4-level grayscale or EGA-like color
      8  = closer to early VGA
    
    COLOR_DITHER controls whether color channels are dithered
    independently (true = Atari/Amiga color, false = Mac grayscale).
    
    Single-pixel sample; safe for Hyprland damage tracking.
    
    by @snes19xx, https://github.com/snes19xx
*/
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// --- Tunables ---
const float PALETTE_SIZE  = 6.0;   // output levels per channel
const bool  COLOR_DITHER  = true;  // false = grayscale dither only
const vec3  TINT_LIGHT    = vec3(0.95, 0.93, 0.88); 
const vec3  TINT_DARK     = vec3(0.10, 0.08, 0.14); 

// --- 4x4 Bayer Matrix ---
// Values are in range [0, 15]. Divide by 16.0 to get [0, 0.9375].
// This defines the threshold map for ordered dithering.
float bayer4x4(ivec2 pos) {
    const int bayer[16] = int[16](
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    );
    int idx = (pos.y % 4) * 4 + (pos.x % 4);
    return float(bayer[idx]) / 16.0;
}

float dither(float value, float threshold) {
    float step   = 1.0 / (PALETTE_SIZE - 1.0);
    float biased = value + (threshold - 0.5) * step;
    return clamp(floor(biased / step + 0.5) * step, 0.0, 1.0);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color    = pixColor.rgb;
\
    ivec2 pixPos  = ivec2(gl_FragCoord.xy);
    float thresh  = bayer4x4(pixPos);

    vec3 result;

    if (COLOR_DITHER) {
        // Independent per-channel dithering.
        result = vec3(
            dither(color.r, thresh),
            dither(color.g, thresh),
            dither(color.b, thresh)
        );
    } else {
        // Luma-only dithering, then re-tint with paper/ink colors.
        float luma    = dot(color, vec3(0.299, 0.587, 0.114));
        float dLuma   = dither(luma, thresh);
        result        = mix(TINT_DARK, TINT_LIGHT, dLuma);
    }

    fragColor = vec4(result, pixColor.a);
}