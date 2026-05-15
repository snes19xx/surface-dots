#version 320 es

/*
    FOR LEARNING/PARTY TRICK PURPOSE ONLY

    TERRIBLE FOR EYES!!!!! 
    PLEASE DO NOT LOOK AT IT FOR MORE THAN A MINUTE OR TWO!

    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float BRIGHTNESS  = 1.4;   // Dim signal
const float NOISE_LEVEL = 0.06;  // Sensor static
const float VIGNETTE    = 0.65;  // Eyepiece falloff radius

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);

    float luma = dot(pixColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    luma *= BRIGHTNESS;

    float noise = (hash(gl_FragCoord.xy * 0.5) - 0.5) * NOISE_LEVEL;
    luma = clamp(luma + noise, 0.0, 1.0);
    luma = smoothstep(0.05, 0.95, luma);

    // Circular eyepiece vignette
    vec2 uv = v_texcoord - 0.5;
    float dist = length(uv);
    float mask = 1.0 - smoothstep(VIGNETTE, VIGNETTE + 0.25, dist);
    luma *= mask;
    
    vec3 phosphor = mix(vec3(0.0, 0.0, 0.0), vec3(0.18, 1.0, 0.22), luma);
    phosphor += vec3(0.0, 0.0, 0.0) * (1.0 - luma); // keep shadows pure black

    fragColor = vec4(clamp(phosphor, 0.0, 1.0), pixColor.a);
}