import QtQuick
import "../Motion.js" as Motion

// The two glows behind the hourglass: the colour halo and the frozen aura.
// The pulses follow the effects clock, not a QML animation.
Item {
    id: root

    required property real size
    required property bool gotStyle
    required property bool ringing
    required property bool reducedMotion
    required property real frost
    required property real fxTime
    required property color sandColor
    required property color frostColor

    anchors.fill: parent

    Item {
        anchors.fill: parent
        opacity: 1 - root.frost

        Halo {
            size: root.size
            gotStyle: root.gotStyle
            tint: root.sandColor
            // Ringing: breathes between 0.3 and 1 every 1.2 s.
            opacity: root.ringing ? Motion.wave(root.fxTime, 1.2, 0.3, 1) : 0.4
        }
    }

    // Frozen aura: breathes slowly, even when frozen (still with Reduce motion).
    Item {
        anchors.fill: parent
        opacity: root.frost
        visible: root.frost > 0.005

        Halo {
            size: root.size
            gotStyle: root.gotStyle
            tint: root.frostColor
            scale: 1.12
            opacity: root.reducedMotion ? 0.85 : Motion.wave(root.fxTime, 4.4, 0.7, 1)
        }
    }
}
