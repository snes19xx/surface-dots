#version 320 es

/*
    Please do not use this for more than a party trick.
    by @snes19xx, https://github.com/snes19xx
*/


precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// RADIUS CONFIG
const float RADIUS = 0.3; // Size of the clear circle
const float SOFTNESS = 0.4; // How gradual the fade is
const float DIM_LEVEL = 0.2; // Brightness of the background (0.0 = black)

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    
    // Calculate distance from center 
    vec2 uv = v_texcoord - 0.5;
    // This is for 3:2 please use 1.7777777777777777777 for 16:9 
    uv.x *= 1.5; 
    float dist = length(uv);
    
    // Create the mask (1.0 = center, 0.0 = edge)
    float mask = 1.0 - smoothstep(RADIUS, RADIUS + SOFTNESS, dist);
    
    // Desaturate the dark areas
    float luma = dot(pixColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 grey = vec3(luma);
    
    // Mix: Center is original color, Edges are dim Greyscale
    vec3 finalColor = mix(grey * DIM_LEVEL, pixColor.rgb, mask);
    
    fragColor = vec4(finalColor, pixColor.a);
}