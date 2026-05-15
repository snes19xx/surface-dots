#version 320 es

/*
    Simulates physical canvas geometry and pigment density.
    THIS IS INSPIRED BY MY SAMSUNG 'THE FRAME' TV
    by @snes19xx, https://github.com/snes19xx
*/

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float hash(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Generate a heightmap for the canvas surface
float getCanvasHeight(vec2 pos) {
    float weaveX = sin(pos.x * 2.0);
    float weaveY = sin(pos.y * 2.0);
    float weave = (weaveX + weaveY) * 0.5;
    
    float noise = hash(pos * 0.5) * 0.6 + hash(pos * 1.5) * 0.4;
    
    return weave * 0.2 + noise * 0.8;
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;
    
    vec3 canvasWhite = vec3(0.92, 0.92, 0.92); 
    vec3 pigmentBlack = vec3(0.12, 0.13, 0.14); // Deep charcoal shadow
    
    // Compress dynamic range into the physical palette limits
    color = mix(pigmentBlack, canvasWhite, color);
    
    // Desaturation
    // Digital colors are too pure. Pigments have wider spectrums (also makes it look more 'matte').
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, 0.75);
    
    // 3D Surface & Directional Lighting
    vec2 pos = gl_FragCoord.xy;
    float heightCenter = getCanvasHeight(pos);
    
    // Sample top-left pixel to calculate fake surface normal / bump
    float heightTopLeft = getCanvasHeight(pos + vec2(-1.0, 1.0));
    
    // Simulated spotlight coming from a top-left angle
    float bump = (heightCenter - heightTopLeft);
    
    // Heavy dark paint fills the canvas grain. Light areas show more raw canvas.
    float paintThickness = 1.0 - smoothstep(0.1, 0.9, luma);
    float textureStrength = mix(0.12, 0.03, paintThickness);
    
    // Apply directional highlight/shadow to the bumps
    color += bump * textureStrength;
    
    // Apply ambient occlusion (recessed pits in the canvas are darker)
    color *= (0.92 + 0.08 * heightCenter);
    
    // Spotlight Wash
    vec2 center = v_texcoord - 0.5;
    float dist = length(center);
    float vig = 1.0 - smoothstep(0.3, 1.2, dist) * 0.2;
    
    color *= vec3(1.0, 1.0, 1.0); // Neutral wash
    color *= vig;
    
    fragColor = vec4(clamp(color, 0.0, 1.0), pixColor.a);
}