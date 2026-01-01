import QtQuick
import QtQuick.Effects

// GhostEcho - Creates expanding, blurring ghost copies of notification content
// Captures the actual rendered content and animates multiple fading echoes
//
// Usage:
//   GhostEcho {
//       sourceItem: notificationContainer
//       color: accentColor  // Tints the ghosts
//   }

Item {
    id: root

    // Source item to capture and echo
    property Item sourceItem: null

    // Accent color (used for tinting)
    property color color: "#7ad7ff"

    // Corner radius (for clipping)
    property real radius: 20

    // Number of ghost copies
    property int ghostCount: 3

    // Animation timing
    property int duration: 700
    property int staggerDelay: 80

    // Visual parameters
    property real maxScale: 1.18
    property real maxBlur: 28
    property real peakOpacity: 0.35

    // Start the ghost echo animation
    function start() {
        // Schedule capture after a brief delay to ensure content is rendered
        captureTimer.restart();
    }

    // Stop and reset all ghosts
    function stop() {
        captureTimer.stop();
        for (var i = 0; i < ghostRepeater.count; i++) {
            ghostRepeater.itemAt(i).reset();
        }
    }

    // Brief delay to ensure source content is rendered before capture
    Timer {
        id: captureTimer
        interval: 16  // One frame
        repeat: false
        onTriggered: {
            // Trigger capture by toggling sourceItem binding
            if (root.sourceItem) {
                contentCapture.scheduleUpdate();
                // Start ghost animations with stagger
                for (var i = 0; i < ghostRepeater.count; i++) {
                    ghostRepeater.itemAt(i).startWithDelay(i * root.staggerDelay);
                }
            }
        }
    }

    // Capture source content as texture
    ShaderEffectSource {
        id: contentCapture
        sourceItem: root.sourceItem
        live: false  // Capture once, not continuously
        hideSource: false  // Keep original visible
        visible: false  // This is just a texture source
        textureSize: Qt.size(root.width * 1.5, root.height * 1.5)  // Higher res for quality
    }

    // Ghost copies with staggered animations
    Repeater {
        id: ghostRepeater
        model: root.ghostCount

        Item {
            id: ghostLayer
            anchors.centerIn: parent
            width: root.width
            height: root.height
            opacity: 0
            scale: 1.0
            transformOrigin: Item.Center
            visible: opacity > 0

            // Internal blur value for animation
            property real _blur: 0

            // Intensity decreases for later ghosts
            property real intensityFactor: 1.0 - (index * 0.15)

            function startWithDelay(delay) {
                delayTimer.interval = delay;
                delayTimer.start();
            }

            function reset() {
                delayTimer.stop();
                ghostAnim.stop();
                opacity = 0;
                scale = 1.0;
                _blur = 0;
            }

            Timer {
                id: delayTimer
                repeat: false
                onTriggered: ghostAnim.start()
            }

            // Render captured content with blur and color overlay
            Item {
                id: ghostContent
                anchors.fill: parent

                // The captured content with blur
                MultiEffect {
                    id: blurredContent
                    source: contentCapture
                    anchors.fill: parent
                    blurEnabled: true
                    blurMax: root.maxBlur
                    blur: ghostLayer._blur / root.maxBlur  // Normalize to 0-1
                }

                // Color tint overlay
                Rectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: root.color
                    opacity: 0.15 * ghostLayer.intensityFactor
                }
            }

            ParallelAnimation {
                id: ghostAnim

                // Scale outward
                NumberAnimation {
                    target: ghostLayer
                    property: "scale"
                    from: 1.0
                    to: root.maxScale
                    duration: root.duration
                    easing.type: Easing.OutCubic
                }

                // Opacity: quick fade in, slower fade out
                SequentialAnimation {
                    NumberAnimation {
                        target: ghostLayer
                        property: "opacity"
                        from: 0
                        to: root.peakOpacity * ghostLayer.intensityFactor
                        duration: root.duration * 0.15
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: ghostLayer
                        property: "opacity"
                        to: 0
                        duration: root.duration * 0.85
                        easing.type: Easing.InCubic
                    }
                }

                // Blur increases as ghost expands
                NumberAnimation {
                    target: ghostLayer
                    property: "_blur"
                    from: 0
                    to: root.maxBlur
                    duration: root.duration
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
