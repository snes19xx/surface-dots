#version 320 es

/*
    Smart Inversion
    Converts RGB to HSL, inverts the Lightness channel, and converts back.

    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

vec3 rgb2hsl(vec3 c) {
    float cMin = min(min(c.r, c.g), c.b);
    float cMax = max(max(c.r, c.g), c.b);
    float delta = cMax - cMin;
    float l = (cMax + cMin) / 2.0;
    float h = 0.0;
    float s = 0.0;

    if (delta > 0.0) {
        s = l < 0.5 ? delta / (cMax + cMin) : delta / (2.0 - cMax - cMin);
        if (cMax == c.r) {
            h = (c.g - c.b) / delta + (c.g < c.b ? 6.0 : 0.0);
        } else if (cMax == c.g) {
            h = (c.b - c.r) / delta + 2.0;
        } else {
            h = (c.r - c.g) / delta + 4.0;
        }
        h /= 6.0;
    }
    return vec3(h, s, l);
}

float hue2rgb(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0/2.0) return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

vec3 hsl2rgb(vec3 c) {
    float h = c.x;
    float s = c.y;
    float l = c.z;
    if (s == 0.0) {
        return vec3(l, l, l);
    } else {
        float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
        float p = 2.0 * l - q;
        return vec3(
            hue2rgb(p, q, h + 1.0/3.0),
            hue2rgb(p, q, h),
            hue2rgb(p, q, h - 1.0/3.0)
        );
    }
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 hsl = rgb2hsl(pixColor.rgb);
    
    // Invert lightness
    hsl.z = 1.0 - hsl.z;
    
    // Contrast bump to prevent flat midtones
    hsl.z = smoothstep(0.02, 0.98, hsl.z);

    vec3 finalColor = hsl2rgb(hsl);
    fragColor = vec4(finalColor, pixColor.a);
}