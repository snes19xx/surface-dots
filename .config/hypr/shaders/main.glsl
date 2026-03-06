#version 320 es

/*
    This is my main shader, I run it at startup with
    `exec-once = hyprshade on main.glsl`
    It attempts to fix weird blurry scalling and dull colors on my surface laptop's 
    high dpi display. It's a lightweight color-grading pass that restores 
    that premium punchy look without crushing blacks or looking fake.
    It's also extremely efficient. No neighbor sampling, no heavy math.

    [strictly tuned for my taste and my specific display]
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;


// CONFIG
const float CONTRAST = 1.08;
const float VIBRANCE = 0.07;  
const float SATURATION = 1.03; 
// No Sharpening = No Glitches with Damage Tracking

// MAIN
void main() {

    // Fetch CURRENT pixel only (No neighbors)
    // reading neighbors (textureOffset) breaks 
    // hyprland's damage tracking and forces 60fps redraws. this doesn't.
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    // Contrast (S-Curve for clarity)
    // Centers around 0.5 (gray) 
    color = (color - 0.5) * CONTRAST + 0.5;

    // standard coefficients for how human eyes perceive brightness.
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Vibrance & Saturation
    float max_c = max(color.r, max(color.g, color.b));
    float min_c = min(color.r, min(color.g, color.b));
    float sat = max_c - min_c;
    
    // Skin-tone protect
    float skinProtect = smoothstep(0.3, 0.6, color.r) * smoothstep(0.6, 0.3, color.g) * 0.5;
    color = mix(vec3(luma), color, 1.0 + (VIBRANCE * (1.0 - sat) * (1.0 - skinProtect)));
    
    // Global Sat
    luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, SATURATION);

    // output
    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}