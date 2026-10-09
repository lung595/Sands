import QtQuick
import "Geometry.js" as Geometry

// Where the sand is: the displayed fraction and the levels derived from it.
QtObject {
    id: root

    // Remaining fraction at the top (1 = full, 0 = empty), and the geometry
    // (Geometry.dimensions) and its volume table (Geometry.volumes).
    required property real progress
    required property var dim
    required property var vol

    // Displayed sand: follows `progress` smoothly, but jumps at once on
    // a big change (restart: the flip is what animates).
    property real shownProgress: progress
    Behavior on shownProgress {
        // Smoothed only for a real visible jump (+1 min, short timer);
        // neither for an invisible step nor for a flip (> 50%).
        enabled: Math.abs(root.progress - root.shownProgress) < 0.5 && Math.abs(root.progress - root.shownProgress) > 0.004
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    // Recomputed when the sand moves, not every frame.
    readonly property var levels: Geometry.sand(dim, vol, shownProgress)
    readonly property real topU: levels.topU
    readonly property real bottomU: levels.bottomU
    readonly property real moundH: levels.moundH
    readonly property real fallLength: levels.fallLength
    // Levels at quarter-pixel precision: the glass is only repainted when the
    // sand visibly moved (not every second of a long timer).
    readonly property real topPx: Math.round((1 - topU) * dim.bulbL * 4)
    readonly property real bottomPx: Math.round((1 - bottomU) * dim.bulbL * 4)
}
