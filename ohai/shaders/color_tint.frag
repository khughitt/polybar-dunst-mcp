#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Tint color (RGB)
    float tintR;
    float tintG;
    float tintB;
    // Tint intensity (0.0 = original, 1.0 = fully tinted)
    float intensity;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 texColor = texture(source, uv);

    // Use alpha channel as the mask (works with any fill color)
    // This allows tinting black/white/colored sources equally
    vec3 tintColor = vec3(tintR, tintG, tintB);

    // Calculate luminance for blending with original
    float luminance = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));

    // For dark sources (like black fills), use alpha directly
    // For light sources, preserve luminance-based shading
    float maskValue = max(luminance, texColor.a * 0.9);

    vec3 tinted = maskValue * tintColor;

    // Mix between original and tinted based on intensity
    vec3 result = mix(texColor.rgb, tinted, intensity);

    fragColor = vec4(result, texColor.a) * qt_Opacity;
}
