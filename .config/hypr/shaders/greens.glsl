#version 320 es

/*
    Green Isolation
    Retains only green hues and desaturates all other colors to grayscale.
    Single-pixel sample; safe for damage tracking.

    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    vec3 hsv = rgb2hsv(color);
    
    // Target hue for Green is ~0.33 on a 0.0 to 1.0 scale
    float targetHue = 0.33;
    
    // Calculate shortest distance on the circular hue color wheel
    float dist = abs(hsv.x - targetHue);
    dist = min(dist, 1.0 - dist);
    
    // Create a mask based on hue distance
    // Values closer to targetHue stay 1.0, further away fall off to 0.0
    float greenMask = 1.0 - smoothstep(0.08, 0.16, dist);
    
    // Prevent near-white, near-black, or gray pixels from identifying as green
    greenMask *= smoothstep(0.15, 0.25, hsv.y); // Saturation 
    greenMask *= smoothstep(0.10, 0.20, hsv.z); // Brightness

    // Calculate perceptual luminance for the non-green areas
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Mix the original color with the grayscale version based on the mask
    vec3 finalColor = mix(vec3(luma), color, greenMask);

    fragColor = vec4(clamp(finalColor, 0.0, 1.0), pixColor.a);
}