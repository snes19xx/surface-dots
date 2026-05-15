#version 320 es
/*
    Pacific Northwest / Silent Hill Shader
    Single-pixel sample; safe for Hyprland damage tracking.

    by @snes19xx, https://github.com/snes19xx
    
*/
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// --- Palette ---
const vec3 SHADOW_COLOR    = vec3(0.13, 0.11, 0.10);
const vec3 FOG_COLOR       = vec3(0.58, 0.54, 0.48);
const vec3 HIGHLIGHT_COLOR = vec3(0.91, 0.89, 0.85);

// --- Noise ---
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// --- Saturation ---
vec3 setSaturation(vec3 col, float sat) {
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    return mix(vec3(lum), col, sat);
}

// --- Hue detection helpers ---
// Returns how "green" a color is, weighted to avoid picking up yellows.
float greenness(vec3 c) {
    return max(0.0, c.g - max(c.r, c.b) * 0.85);
}
// Returns how "red/warm" a color is — the one hue Silent Hill keeps alive.
float redness(vec3 c) {
    return max(0.0, c.r - max(c.g, c.b));
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color    = pixColor.rgb;

    float luma = dot(color, vec3(0.299, 0.587, 0.114));

    // -------------------------------------------------------------------------
    // BASE DESATURATION
    // -------------------------------------------------------------------------
    // Pulls almost all color out of the scene. The air itself is
    // the dominant visual element. Start by crushing saturation hard.
    // EXCEPT this hue below:
    color = setSaturation(color, 0.25);

    // -------------------------------------------------------------------------
    // SUPRESSION OF GREEN CHANNEL
    // -------------------------------------------------------------------------
    vec3 orig = pixColor.rgb;
    float green = greenness(orig);
    // Pull detected green pixels toward a muted khaki-olive rather than grey.
    // This makes vegetation feel decayed rather than just desaturated.
    vec3 khaki = vec3(0.42, 0.40, 0.28);
    float greenBlend = clamp(green * 2.8, 0.0, 0.55);
    color = mix(color, mix(color, khaki, 0.6), greenBlend);

    // -------------------------------------------------------------------------
    // THREE-ZONE FOG TONING
    // -------------------------------------------------------------------------
    // Shadows: lifted off true black 
    // Midtones: pulled hard toward the warm-grey fog color.
    //           This is where most of the scene lives in Silent Hill;
    //           the fog compresses the tonal range toward the middle.
    // Highlights: blown out to pale overcast
    //
    // Key: the fog is DENSER in the midtones than at the extremes.
    // smoothstep curves give us a soft but controlled remap.
    float shadowT    = smoothstep(0.0,  0.35, luma);
    float fogPeak    = 1.0 - abs(luma - 0.48) / 0.48; // peaks at luma 0.48
    fogPeak          = clamp(fogPeak, 0.0, 1.0);
    float highlightT = smoothstep(0.60, 1.0,  luma);

    vec3 toned = mix(SHADOW_COLOR, color, shadowT);      // lift the shadows
    toned      = mix(toned, FOG_COLOR, fogPeak * 0.55);  // compress midtones into fog
    toned      = mix(toned, HIGHLIGHT_COLOR, highlightT * 0.7); // bleach highlights

    color = toned;

    // -------------------------------------------------------------------------
    // RED PRESERVATION 
    // -------------------------------------------------------------------------
    float red = redness(orig);
    float redLuminance = smoothstep(0.05, 0.55, luma); // reds in near-black are still ash
    float redBlend = clamp(red * 3.0 * redLuminance, 0.0, 0.80);

    vec3 boostedRed = setSaturation(orig, 1.5);
    // Pull the hue slightly toward rust/dried blood (desaturate green channel).
    boostedRed.g *= 0.75;
    color = mix(color, boostedRed, redBlend);

    // -------------------------------------------------------------------------
    // ATMOSPHERIC FOG LIFT
    // -------------------------------------------------------------------------
    // Simulate by adding a small constant fog term weighted toward highlights.
    float fogLift = smoothstep(0.3, 1.0, luma) * 0.06;
    color += FOG_COLOR * fogLift;

    // -------------------------------------------------------------------------
    // ASH / PARTICULATE GRAIN
    // -------------------------------------------------------------------------
    float n1    = hash(gl_FragCoord.xy * 0.53);
    float n2    = hash(gl_FragCoord.xy * 0.19 + 43.7);
    float ash   = n1 * 0.7 + n2 * 0.3 - 0.5;

    // Ash grain is visible in midtones and highlights, fades in deep shadow.
    float ashMask = smoothstep(0.15, 0.6, luma);
    // Occasional brighter specks (individual ash particles catching light).
    float sparkle = step(0.97, n1) * 0.12 * ashMask;

    color += ash * ashMask * 0.045 + sparkle;

    // -------------------------------------------------------------------------
    // SLIGHT VIGNETTE
    // -------------------------------------------------------------------------
    vec2  uv       = v_texcoord - 0.5;
    float vignette = 1.0 - dot(uv, uv) * 1.1;
    vignette       = clamp(vignette, 0.0, 1.0);
    color = mix(FOG_COLOR * 0.75, color, vignette);

    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}