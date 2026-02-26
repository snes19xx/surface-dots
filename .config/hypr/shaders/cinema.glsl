#version 320 es

/*
    Cinema color grade for my media consumption needs.
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float STRENGTH    = 0.7;
const float CONTRAST    = 1.03;
const float ACUTANCE    = 0.2;

const vec3 LIFT_COLOR   = vec3(0.00, 0.02, 0.04);
const float LIFT_LEVEL  = 0.005;
const vec3 GAMMA_CURVE  = vec3(0.98, 0.99, 1.02); // < 1.0 = brighter, > 1.0 = darker
const vec3 GAIN_TINT    = vec3(1.02, 1.00, 0.97);

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color    = pixColor.rgb;
    vec3 original = color;

    // Lift
    float liftMask = 1.0 - smoothstep(0.0, 0.3, luma(color));
    color += (LIFT_COLOR * liftMask) + LIFT_LEVEL;

    // Gamma
    color = pow(max(color, 0.0), GAMMA_CURVE);

    // Gain
    float gainMask = smoothstep(0.5, 1.0, luma(color));
    color = mix(color, color * GAIN_TINT, gainMask);

    // Contrast
    color = 0.5 + (color - 0.5) * CONTRAST;

    // Acutance
    float l = luma(color);
    float acutanceMask = smoothstep(0.05, 0.2, l) * smoothstep(0.95, 0.8, l);
    color -= vec3(length(fwidth(l)) * ACUTANCE * acutanceMask);

    color = mix(original, color, STRENGTH);
    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}