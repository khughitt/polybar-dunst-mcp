import QtQuick

// ColorTintEffect - Applies a color tint to an image based on luminance
// Usage: Apply as layer.effect on any Image or Item
//
// Example:
//   Image {
//       source: "ghost.svg"
//       layer.enabled: true
//       layer.effect: ColorTintEffect {
//           tintColor: "#ff6b6b"
//           intensity: 1.0
//       }
//   }

ShaderEffect {
    id: effect

    // The color to tint the image with
    property color tintColor: "#ffffff"

    // Tint intensity (0.0 = original colors, 1.0 = fully tinted)
    property real intensity: 1.0

    // Extract RGB components for shader uniforms
    property real tintR: tintColor.r
    property real tintG: tintColor.g
    property real tintB: tintColor.b

    fragmentShader: Qt.resolvedUrl("../shaders/color_tint.frag.qsb")
    vertexShader: Qt.resolvedUrl("../shaders/color_tint.vert.qsb")
}
