import QtQuick
import qs.Common
import "Motion.js" as Motion

// Frost dust: fine suspended crystals that sparkle around the hourglass,
// on the hourglass effects clock (fxTime), like FrostMist.
Item {
    id: root

    required property real frost
    required property bool reducedMotion
    required property real fxTime

    anchors.fill: parent
    opacity: frost

    Repeater {
        model: 16

        // Carrier positioned once; the crystal moves inside it.
        Item {
            id: slot
            required property int index
            readonly property real h1: Math.abs(Math.sin(index * 91.7) * 43758.5) % 1
            readonly property real h2: Math.abs(Math.sin(index * 17.3) * 24634.6) % 1
            readonly property real h3: Math.abs(Math.sin(index * 53.1) * 12345.6) % 1
            // Spread around the hourglass, not on it
            readonly property real ang: index / 16 * Math.PI * 2 + h1 * 0.4
            readonly property real dist: 0.34 + h2 * 0.14
            x: root.width / 2 + Math.cos(ang) * root.height * dist * 0.85
            y: root.height / 2 + Math.sin(ang) * root.height * dist

            Rectangle {
                width: 1.5 + slot.h3 * 2
                height: width
                radius: width / 2
                x: -width / 2
                color: Theme.surfaceText
                // Reduce motion: the crystals stay still, dimly lit.
                opacity: root.reducedMotion ? 0.3 : Motion.sparkle(root.fxTime * 1000, slot.h1, slot.h2, slot.h3)
                y: root.reducedMotion ? 0 : Motion.drift(root.fxTime * 1000, slot.h2, slot.h3)
            }
        }
    }
}
