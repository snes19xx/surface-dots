#version 320 es

/*
    Gameboy 4-color simulation.
    Uses luma and a 4x4 Bayer matrix to dither gradients into 4 solid colors.
    Single-pixel sample. Damage tracking remains intact.
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const vec3 GB_0 = vec3(0.059, 0.219, 0.059);   // Darkest
const vec3 GB_1 = vec3(0.188, 0.384, 0.188);   // Dark
const vec3 GB_2 = vec3(0.545, 0.675, 0.059);   // Light
const vec3 GB_3 = vec3(0.608, 0.737, 0.059);   // Lightest

float getBayer(vec2 pos) {
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    const mat4 bayer = mat4(
        0.0, 12.0,  3.0, 15.0,
        8.0,  4.0, 11.0,  7.0,
        2.0, 14.0,  1.0, 13.0,
        10.0,  6.0,  9.0,  5.0
    );
    return bayer[x][y] / 16.0;
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    float luma = dot(pixColor.rgb, vec3(0.299, 0.587, 0.114));
    
    vec2 screenPos = gl_FragCoord.xy;
    float bayerValue = getBayer(screenPos);
    
    // Add dither threshold
    float ditheredLuma = luma + (bayerValue - 0.5) * 0.25;
    
    // Quantize into 4 steps
    float step = floor(ditheredLuma * 3.99);
    
    vec3 finalColor;
    if (step < 1.0) finalColor = GB_0;
    else if (step < 2.0) finalColor = GB_1;
    else if (step < 3.0) finalColor = GB_2;
    else finalColor = GB_3;

    fragColor = vec4(finalColor, pixColor.a);
}