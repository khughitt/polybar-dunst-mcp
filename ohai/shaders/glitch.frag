#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Custom uniforms
    float chromatic;      // Chromatic aberration intensity (0.0 - 0.05 typical)
    float displacement;   // Horizontal displacement amount
    float noiseAmount;    // Noise/static intensity (0.0 - 1.0)
    float time;           // Time for noise animation
    float scanlineAlpha;  // Scanline darkness (0.0 - 0.3 typical)
};

layout(binding = 1) uniform sampler2D source;

// Simple pseudo-random function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // Apply horizontal displacement
    uv.x += displacement;

    // Chromatic aberration - offset RGB channels
    float r = texture(source, uv + vec2(chromatic, 0.0)).r;
    float g = texture(source, uv).g;
    float b = texture(source, uv - vec2(chromatic, 0.0)).b;
    float a = texture(source, uv).a;

    vec4 color = vec4(r, g, b, a);

    // Add noise/static
    if (noiseAmount > 0.0) {
        float noise = random(uv + vec2(time, time * 0.7)) * noiseAmount;
        color.rgb += vec3(noise) * a;
    }

    // Add scanlines (subtle horizontal lines)
    if (scanlineAlpha > 0.0) {
        float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
        color.rgb -= vec3(scanline * scanlineAlpha) * a;
    }

    fragColor = color * qt_Opacity;
}
