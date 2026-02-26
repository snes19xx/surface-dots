#version 320 es

/*
    Simulates a loose watercolor wash; soft, painterly look. 
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Paper white
const vec3 PAPER = vec3(0.97, 0.95, 0.90);

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float paperSizing(vec2 uv) {
    float n = 0.0;
    n += hash(uv * 0.2) * 0.5;
    n += hash(uv * 0.7) * 0.3;
    n += hash(uv * 2.1) * 0.2;
    return n; // [0, 1] uneven absorption
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    float granulation = smoothstep(0.3, 0.75, luma);
    color = mix(color, vec3(luma), granulation * 0.45);

    float dilution = smoothstep(0.55, 1.0, luma);
    color = mix(color, PAPER, dilution * 0.5);

    float sizing = paperSizing(gl_FragCoord.xy * 0.12);
    float paperContrib = sizing * 0.04;
    color = mix(color, PAPER, paperContrib * (1.0 - luma));

    // Slight warm tint overall
    color.r += 0.012;
    color.b -= 0.008;

    vec2 uv = v_texcoord - 0.5;
    float vig = 1.0 - smoothstep(0.3, 1.0, length(uv)) * 0.18;
    color *= vig;

    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}