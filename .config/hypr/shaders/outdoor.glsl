#version 320 es

/*
    For maximum outdoor useability.
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Tune these for your display's nit ceiling
const float GAMMA       = 0.75;   // < 1.0 = brighter midtones. 0.7-0.8 is a good range.
const float CONTRAST    = 1.22;   // Punch edges harder
const float CLARITY     = 0.18;   // Local-contrast feel via luma curve steepening at midpoint
const float SAT_BOOST   = 0.85;   // Slightly desaturate - color accuracy matters less than legibility

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    // Gamma lift: moves midtones toward white to compete with ambient light
    color = pow(clamp(color, 0.001, 1.0), vec3(GAMMA));

    // Contrast around the midpoint
    color = clamp((color - 0.5) * CONTRAST + 0.5, 0.0, 1.0);

    // This is where text anti-aliasing, UI borders, and icons are.
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float clarityMask = smoothstep(0.3, 0.5, luma) * (1.0 - smoothstep(0.5, 0.7, luma));
    color += (color - 0.5) * clarityMask * CLARITY;

    // Pull back saturation a little
    luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, SAT_BOOST);

    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}