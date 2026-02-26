#version 320 es

/*
    Proper blue-light reduction (This one's genuinely useful!)
    
    This version scales blue reduction by luminance:
    bright whites get the full warm shift, dark areas are left alone.
    
    The target color temperature is approximately 3200K (candlelight).
    Raise WARMTH toward 1.0 for 2700K (incandescent), lower for 4000K (halogen).

    by @snes19xx, https://github.com/snes19xx
    
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float WARMTH  = 0.72;  // 0.0 = no change, 1.0 = maximum warmth
const float DIMMING = 0.88;  // Overall brightness reduction. Eyes need less at night.

// Approximate D65 -> 3200K chromatic adaptation coefficients
// These are derived from the Bradford matrix, simplified for single-pass use.
// R gains slightly, G is near-neutral, B is cut significantly.
const vec3 WARM_GAIN = vec3(1.06, 0.96, 0.52);

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Only apply warmth shift proportional to luminance.
    // A pixel at luma 0.9 (near white) gets full warm gain.
    // A pixel at luma 0.1 (near black) gets almost none.
    // This preserves dark-mode shadow detail completely.
    float warmthMask = pow(luma, 0.6); // softer than linear - protects midtones too
    
    vec3 warmed = color * WARM_GAIN;
    color = mix(color, warmed, warmthMask * WARMTH);

    // Overall dimming 
    color *= DIMMING;

    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}