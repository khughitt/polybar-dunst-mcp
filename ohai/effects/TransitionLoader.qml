import QtQuick

// TransitionLoader - Dynamic loader for transition effects
// Provides a unified interface for multiple effect types
//
// Usage:
//   TransitionLoader {
//       effectType: "ghost"  // glow, ghost, ripple, none
//       color: accentColor
//       sourceItem: notificationContainer
//   }

Item {
    id: root

    // Effect type to load: "glow", "ghost", "ripple", "none"
    property string effectType: "glow"

    // Common properties passed to all effects
    property color color: "#7ad7ff"
    property real radius: 20
    property Item sourceItem: null

    // Trigger the transition animation
    function start() {
        if (loader.item && typeof loader.item.start === "function") {
            loader.item.start();
        }
    }

    // Stop and reset the transition
    function stop() {
        if (loader.item && typeof loader.item.stop === "function") {
            loader.item.stop();
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: root.effectType !== "none" && root.effectType !== ""

        source: {
            switch (root.effectType) {
                case "ghost": return "GhostEcho.qml";
                case "ripple": return "RippleEcho.qml";
                case "glow": return "GlowPulse.qml";
                default: return "";
            }
        }

        onLoaded: {
            // Bind common properties
            if (item.color !== undefined)
                item.color = Qt.binding(() => root.color);
            if (item.radius !== undefined)
                item.radius = Qt.binding(() => root.radius);
            if (item.sourceItem !== undefined)
                item.sourceItem = Qt.binding(() => root.sourceItem);

            // Set size bindings
            item.width = Qt.binding(() => root.width);
            item.height = Qt.binding(() => root.height);
        }
    }
}
