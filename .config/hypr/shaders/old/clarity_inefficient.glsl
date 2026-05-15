#version 320 es

/* [DISABLES DAMAGE TRACKING]
FOR REFERENCE ONLY -- DO NOT USE !!!! */

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;


const float SHARPNESS = 0.5;
const float UNSHARP_STRENGTH = 0.4;

// SUBTLE COLOR ENHANCEMENT
const float VIBRANCE = 0.07;        
const float SATURATION = 1.03;    

// CONTRAST: Helps text clarity
const float CONTRAST = 1.08;

// CLARITY: Mid-tone contrast
const float CLARITY = 0.10;

// ANTI-ALIAS: Reduces sharpening artifacts
const float AA_THRESHOLD = 0.25;

float min3(vec3 v) { return min(min(v.r, v.g), v.b); }
float max3(vec3 v) { return max(max(v.r, v.g), v.b); }


void main() {
    vec3 e = texture(tex, v_texcoord).rgb;
    vec3 n = textureOffset(tex, v_texcoord, ivec2( 0, -1)).rgb;
    vec3 s = textureOffset(tex, v_texcoord, ivec2( 0,  1)).rgb;
    vec3 w = textureOffset(tex, v_texcoord, ivec2(-1,  0)).rgb;
    vec3 east = textureOffset(tex, v_texcoord, ivec2( 1,  0)).rgb;

    float mn = min3(e);
    mn = min(mn, min3(n));
    mn = min(mn, min3(s));
    mn = min(mn, min3(w));
    mn = min(mn, min3(east));
    
    float mx = max3(e);
    mx = max(mx, max3(n));
    mx = max(mx, max3(s));
    mx = max(mx, max3(w));
    mx = max(mx, max3(east));
    
    float edgeStrength = mx - mn;
    float adaptiveSharp = SHARPNESS * (1.0 - smoothstep(0.0, AA_THRESHOLD, edgeStrength));
    
    // CAS formula
    float amp = clamp(min(mn, 2.0 - mx) / max(mx, 0.0001), 0.0, 1.0);
    amp = sqrt(amp);
    float peak = -3.0 * adaptiveSharp + 8.0;
    float w_cas = amp / peak;
    
    vec3 rcpWeight = vec3(1.0 / (1.0 + 4.0 * w_cas));
    vec3 sharp1 = (e + (n + s + w + east) * w_cas) * rcpWeight;
    
    vec3 nw = textureOffset(tex, v_texcoord, ivec2(-1, -1)).rgb;
    vec3 ne = textureOffset(tex, v_texcoord, ivec2( 1, -1)).rgb;
    vec3 sw = textureOffset(tex, v_texcoord, ivec2(-1,  1)).rgb;
    vec3 se = textureOffset(tex, v_texcoord, ivec2( 1,  1)).rgb;

    vec3 blurred = (e * 4.0 + (n + s + w + east) * 2.0 + (nw + ne + sw + se)) / 16.0;
    
    vec3 color = sharp1 + (sharp1 - blurred) * UNSHARP_STRENGTH;
    
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    color = (color - 0.5) * CONTRAST + 0.5;
    
    // Clarity (local contrast boost for mid-tones)
    float clarityMask = smoothstep(0.2, 0.5, luma) * smoothstep(0.8, 0.5, luma);
    float localContrast = (luma - dot(blurred, vec3(0.299, 0.587, 0.114))) * CLARITY;
    color += localContrast * clarityMask;
    
    // Recalculate luma after contrast adjustment
    luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Subtle vibrance
    float max_c = max3(color);
    float min_c = min(min(color.r, color.g), color.b);
    float sat = max_c - min_c;
    
    // Skin tone protection
    float skinProtect = smoothstep(0.25, 0.55, color.r) * 
                        smoothstep(0.6, 0.35, color.g) *
                        smoothstep(0.5, 0.2, color.b) * 0.6;
    
    float vibranceAmount = VIBRANCE * (1.0 - sat) * (1.0 - skinProtect);
    color = mix(vec3(luma), color, 1.0 + vibranceAmount);
    
    // Very subtle global saturation boost
    luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, SATURATION);
    
    // FINAL OUTPUT
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}