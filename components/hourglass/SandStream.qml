pragma ComponentBehavior: Bound
import QtQuick

// The stream of grains through the neck: computed positions, no repaint.
// Frozen, the clock stops: the grains stay suspended.
Item {
    id: root

    required property bool flowing
    required property var dim
    required property real fallLength
    // Grain clock (MotionClock.clock).
    required property real clock
    required property real frost
    required property color sandColor
    required property color frostColor

    anchors.fill: parent

    Rectangle {
        visible: root.flowing
        x: (parent.width - width) / 2
        y: parent.height / 2 + root.dim.neck
        width: Math.max(1, root.dim.neck * 0.45)
        height: root.fallLength
        radius: width / 2
        color: root.sandColor
        opacity: 0.3 * (1 - root.frost * 0.5)
    }

    Repeater {
        model: root.flowing ? 11 : 0

        Rectangle {
            required property int index
            readonly property real phase: root.clock * 1.7 + index / 11
            readonly property real q: phase - Math.floor(phase)
            readonly property real seed: Math.sin((index + Math.floor(phase) * 13) * 127.1) * 43758.5453
            readonly property real jitter: seed - Math.floor(seed)
            width: Math.max(1.8, root.dim.hgW * 0.022) * (0.8 + 0.4 * jitter)
            height: width
            radius: width / 2
            x: root.width / 2 - width / 2 + (jitter - 0.5) * root.dim.neck * 0.9
            y: root.height / 2 + root.dim.neck + Math.pow(q, 1.5) * root.fallLength - height / 2
            color: Qt.tint(Qt.lighter(root.sandColor, 1.25), Qt.rgba(root.frostColor.r, root.frostColor.g, root.frostColor.b, root.frost * 0.6))
        }
    }
}
