import QtQuick

// RippleEcho - Creates ghostly rippling border echoes that propagate outward
// Place this behind the main notification content and trigger with start()

Item {
    id: root

    // Border color for the ripples
    property color color: "#7ad7ff"

    // Corner radius to match the notification
    property real radius: 20

    // Number of ripple waves
    property int waveCount: 3

    // Duration for each ripple to complete (ms)
    property int rippleDuration: 800

    // Maximum scale the ripples expand to
    property real maxScale: 1.15

    // Stagger delay between each ripple wave (ms)
    property int staggerDelay: 120

    // Border width of the ripples (starting width)
    property real borderWidth: 2.0

    // Peak opacity (softer = lower value)
    property real peakOpacity: 0.45

    // Start the ripple animation
    function start() {
        for (var i = 0; i < rippleRepeater.count; i++) {
            rippleRepeater.itemAt(i).start(i * staggerDelay);
        }
    }

    // Stop and reset all ripples
    function stop() {
        for (var i = 0; i < rippleRepeater.count; i++) {
            rippleRepeater.itemAt(i).reset();
        }
    }

    Repeater {
        id: rippleRepeater
        model: root.waveCount

        Rectangle {
            id: ripple
            anchors.centerIn: parent
            width: root.width
            height: root.height
            radius: root.radius
            color: "transparent"
            border.color: root.color
            border.width: root.borderWidth
            opacity: 0
            scale: 1.0
            transformOrigin: Item.Center

            function start(delay) {
                delayTimer.interval = delay;
                delayTimer.start();
            }

            function reset() {
                delayTimer.stop();
                rippleAnim.stop();
                opacity = 0;
                scale = 1.0;
                border.width = root.borderWidth;
            }

            Timer {
                id: delayTimer
                repeat: false
                onTriggered: rippleAnim.start()
            }

            ParallelAnimation {
                id: rippleAnim

                // Scale outward with gentle easing
                NumberAnimation {
                    target: ripple
                    property: "scale"
                    from: 1.0
                    to: root.maxScale
                    duration: root.rippleDuration
                    easing.type: Easing.OutCubic
                }

                // Opacity: quick fade in, then smooth fade to zero
                SequentialAnimation {
                    // Quick fade in (10% of duration)
                    NumberAnimation {
                        target: ripple
                        property: "opacity"
                        from: 0
                        to: root.peakOpacity
                        duration: root.rippleDuration * 0.10
                        easing.type: Easing.OutQuad
                    }
                    // Long fade out to zero (90% of duration)
                    NumberAnimation {
                        target: ripple
                        property: "opacity"
                        from: root.peakOpacity
                        to: 0
                        duration: root.rippleDuration * 0.90
                        easing.type: Easing.InCubic
                    }
                }

                // Border width: taper from thick to thin (feathered edge)
                NumberAnimation {
                    target: ripple
                    property: "border.width"
                    from: root.borderWidth
                    to: root.borderWidth * 0.15
                    duration: root.rippleDuration
                    easing.type: Easing.InQuad
                }
            }
        }
    }
}
