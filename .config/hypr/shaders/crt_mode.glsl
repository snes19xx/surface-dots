#version 320 es

/*
    crt.glsl by @snes19xx, https://github.com/snes19xx
    Here I try to use distortions and physical shadow mask to simulate that fuzzy, curved glass effect, 
    shadowy image mostly modifying UVs for geometry and modulating brightness for the grid.

    [CAUTION] - HEAVY POST-PROCESSING
    This shader goes completely against modern compositor logic. It requires full-frame rendering 
    to maintain the CRT illusion, which breaks standard optimizations.

    1. GLITCHES:   Please use `crt_mode.sh` to activate/deactivate this shader. 
                   OR You must disable Hyprland's damage tracking:"keyword debug:damage_tracking 0"
                   Without this, the scanlines and warp will glitch/tear on floating windows 
                   and animations because the compositor will only update changed pixels.

    2. POWER:      Disabling damage tracking forces the GPU to render the full 
                   resolution frame every single refresh cycle. This defeats the purpose of wayland 
                   efficiency. Expect high idle power draw.

    3. HEALTH:     Strictly for aesthetics (retro anime/emulators). 
                   Do not code/read in this. The chromatic aberration and geometric distortion 
                   force your eyes to constantly refocus. It is bad for your eyes.
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// CONSTANTS
const float WARP_X = 0.01;      // horizontal curvature 
const float WARP_Y = 0.015;     // vertical curvature
const float SCAN_STR = 0.15;    // Scanline darkness
const float MASK_STR = 0.20;    // Vertical bars intensity
const float BLOOM_STR = 1.2;    // Glow amount

// Distort coordinates to simulate curved glass: 
// This pushes the uv coordinates out from the center to fake fisheye geometry. 
vec2 warp(vec2 uv) {
    vec2 dc = uv - 0.5;
    float d2 = dot(dc, dc);
    uv += dc * d2 * (vec2(WARP_Y, WARP_X)); 
    return uv;
}

void main() {
    vec2 uv = warp(v_texcoord);
    
    // Check if UV is out of bounds
    // hard cut to black to simulate the plastic bezel
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Electron guns in cheap tvs apparently never aligned the RGB beams perfectly.
    // This fakes that convergence error by jittering the texture slightly.
    float r = texture(tex, uv - vec2(0.001, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv + vec2(0.001, 0.0)).b;
    vec3 color = vec3(r, g, b);
    
    // Scanlines (Horizontal)
    // unlike the random noise in my e-ink shader, I *want* a predictable periodic wave here so I am using sin()
    // it is doing actual math here instead of being a pseudo-random hash function
    float scanline = sin(gl_FragCoord.y * 1.5) * 0.5 + 0.5;
    
    // Phosphor Bleed
    // bright phosphors glow and scatter light. if the pixel is bright,
    // it should bleed over the scanline gap. improves visibility.
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float scan_attenuation = 1.0 - (SCAN_STR * (1.0 - luma));
    
    // apply the scanline darkening mixed with the bleed
    color *= mix(1.0, 0.6 + 0.4 * scanline, SCAN_STR);

    // Vertical Strips
    // simple modulo math to darken every 3rd pixel column.
    if (mod(gl_FragCoord.x, 3.0) < 1.0) {
        color *= (1.0 - MASK_STR);
    }

    // Vignette
    // light has to travel through thicker glass at the edges.
    // standard falloff equation to darken the corners.
    float vig = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vig = pow(vig, 0.15); // flatten the curve so it's only the very edges
    color *= vig;

    // Gain Compensation
    // the image is too dim now becayse of scanlines and masks cover half of the pixels
    // so overdrive the brightness to compensate.
    color *= BLOOM_STR;

    fragColor = vec4(color, 1.0);
}