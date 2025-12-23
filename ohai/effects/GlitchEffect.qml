import QtQuick

// GlitchEffect - Applies chromatic aberration, displacement, noise, and scanlines
// Usage: Apply as layer.effect on any Item, then animate the properties
//
// Example:
//   Item {
//       layer.enabled: true
//       layer.effect: GlitchEffect {
//           chromatic: 0.02
//           NumberAnimation on chromatic { from: 0.05; to: 0; duration: 300 }
//       }
//   }

ShaderEffect {
    id: effect

    // Chromatic aberration intensity (RGB channel separation)
    // Typical range: 0.0 (none) to 0.05 (strong)
    property real chromatic: 0.0

    // Horizontal displacement amount in UV coordinates
    // Typical range: -0.02 to 0.02
    property real displacement: 0.0

    // Noise/static intensity overlay
    // Range: 0.0 (none) to 1.0 (full static)
    property real noiseAmount: 0.0

    // Scanline effect darkness
    // Typical range: 0.0 (none) to 0.3 (visible CRT lines)
    property real scanlineAlpha: 0.0

    // Time value for animating noise (auto-animated)
    property real time: 0.0

    // Internal timer for noise animation
    Timer {
        running: effect.noiseAmount > 0
        interval: 50
        repeat: true
        onTriggered: effect.time = (effect.time + 0.05) % 100.0
    }

    // Shader references - use file:// URLs for local shaders
    fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
    vertexShader: Qt.resolvedUrl("../shaders/glitch.vert.qsb")
}
