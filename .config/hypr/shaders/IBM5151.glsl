#version 320 es

/*
    Inspired by vintage IBM 3278 / 5151 monitors.

    Use monospace font for maximum nostalgia.
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float BRIGHTNESS = 1.05;
const float BLOOM_SOFT = 0.08;   // Fake phosphor glow: just lifts blacks slightly

// Dark amber for shadows, bright warm-white for peaks
const vec3 PHOSPHOR_DARK  = vec3(0.12, 0.06, 0.0);
const vec3 PHOSPHOR_MID   = vec3(0.85, 0.42, 0.0);
const vec3 PHOSPHOR_BRIGHT= vec3(1.0,  0.88, 0.55);

void main() {
    vec4 pixColor = texture(tex, v_texcoord);

    float luma = dot(pixColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    luma = clamp(luma * BRIGHTNESS, 0.0, 1.0);

    // S-curve for terminal-like snap between dark and lit states
    luma = smoothstep(0.06, 0.94, luma);

    // Lift blacks slightly to simulate phosphor glow scatter
    luma = luma + (1.0 - luma) * BLOOM_SOFT * luma;

    // Two-stop color ramp: dark amber -> saturated amber -> bright near-white amber
    vec3 color;
    if (luma < 0.5) {
        color = mix(PHOSPHOR_DARK, PHOSPHOR_MID, luma * 2.0);
    } else {
        color = mix(PHOSPHOR_MID, PHOSPHOR_BRIGHT, (luma - 0.5) * 2.0);
    }

    // Vignette - monitor bezels cut the corners
    vec2 uv = v_texcoord - 0.5;
    float vig = 1.0 - smoothstep(0.38, 0.9, length(uv)) * 0.25;

    fragColor = vec4(clamp(color * vig, 0.0, 1.0), pixColor.a);
}