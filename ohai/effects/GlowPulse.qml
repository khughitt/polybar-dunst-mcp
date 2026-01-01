import QtQuick
import QtQuick.Effects

// GlowPulse - Creates a soft glow/bloom that pulses outward once
// Place this behind the main notification content and trigger with start()

Item {
    id: root

    // Glow color (usually matches accent color)
    property color color: "#7ad7ff"

    // Corner radius to match the notification
    property real radius: 20

    // Source item (unused, for interface compatibility with TransitionLoader)
    property Item sourceItem: null

    // Duration of the pulse animation (ms)
    property int pulseDuration: 600

    // Maximum blur radius at peak
    property real maxBlur: 40

    // Maximum scale the glow expands to
    property real maxScale: 1.08

    // Peak opacity of the glow
    property real peakOpacity: 0.5

    // Internal state
    property real _progress: 0
    property real _opacity: 0

    // Start the glow pulse
    function start() {
        pulseAnimation.restart();
    }

    // Stop and reset
    function stop() {
        pulseAnimation.stop();
        _progress = 0;
        _opacity = 0;
    }

    // Glow source shape
    Rectangle {
        id: glowSource
        anchors.centerIn: parent
        width: root.width
        height: root.height
        radius: root.radius
        color: root.color
        visible: false  // Hidden, used as source for blur
    }

    // Blurred glow layer
    MultiEffect {
        id: glowEffect
        source: glowSource
        anchors.centerIn: parent
        width: root.width
        height: root.height

        // Scale based on progress
        scale: 1.0 + (root.maxScale - 1.0) * root._progress
        transformOrigin: Item.Center

        // Blur increases then decreases
        blurEnabled: true
        blurMax: root.maxBlur
        blur: root._progress * 0.8  // 0 to 0.8 range for blur

        // Opacity pulse
        opacity: root._opacity
    }

    // Secondary inner glow for extra softness
    Rectangle {
        id: innerGlow
        anchors.centerIn: parent
        width: root.width + 4
        height: root.height + 4
        radius: root.radius + 2
        color: "transparent"
        border.color: root.color
        border.width: 3
        opacity: root._opacity * 0.6
        scale: 1.0 + (root.maxScale - 1.0) * root._progress * 0.5
        transformOrigin: Item.Center
    }

    SequentialAnimation {
        id: pulseAnimation

        ParallelAnimation {
            // Progress ramps up
            NumberAnimation {
                target: root
                property: "_progress"
                from: 0
                to: 1
                duration: root.pulseDuration
                easing.type: Easing.OutCubic
            }

            // Opacity: quick rise, slower fall
            SequentialAnimation {
                NumberAnimation {
                    target: root
                    property: "_opacity"
                    from: 0
                    to: root.peakOpacity
                    duration: root.pulseDuration * 0.2
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: root
                    property: "_opacity"
                    from: root.peakOpacity
                    to: 0
                    duration: root.pulseDuration * 0.8
                    easing.type: Easing.InCubic
                }
            }
        }

        // Reset state
        ScriptAction {
            script: {
                root._progress = 0;
                root._opacity = 0;
            }
        }
    }
}
