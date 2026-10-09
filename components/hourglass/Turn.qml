import QtQuick

// The two finite gestures of the hourglass: the flip and the wild spin.
// Both end back at rest, so they cost nothing once done; both are skipped
// with Reduce motion or when the panel is closed.
Item {
    id: root

    required property bool animate
    required property bool reducedMotion

    // Rotation (degrees) shared by both gestures; 0 at rest.
    property real flipAngle: 0
    property real wildHop: 0
    property real wildSquash: 0

    // Flip: the new state (top full) starts upside down and rotates
    // back upright, like a real hourglass being turned over.
    function flip() {
        if (!reducedMotion && animate)
            flipAnim.restart();
    }

    // Wild: a click on the hourglass. Two full turns with a springy hop
    // and a squash on landing, then back to rest (about 1.3 s).
    function wild() {
        if (!reducedMotion && animate)
            wildAnim.restart();
    }

    NumberAnimation {
        id: flipAnim
        target: root
        property: "flipAngle"
        from: 180
        to: 360
        duration: 850
        easing.type: Easing.InOutBack
        easing.overshoot: 1.1
        onFinished: root.flipAngle = 0
    }

    ParallelAnimation {
        id: wildAnim
        NumberAnimation {
            target: root
            property: "flipAngle"
            from: 0
            to: 720
            duration: 1250
            easing.type: Easing.InOutBack
            easing.overshoot: 1.4
        }
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "wildHop"
                to: 1
                duration: 420
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "wildHop"
                to: 0
                duration: 520
                easing.type: Easing.OutBounce
            }
            NumberAnimation {
                target: root
                property: "wildSquash"
                to: 1
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "wildSquash"
                to: 0
                duration: 220
                easing.type: Easing.OutElastic
            }
        }
        onFinished: root.flipAngle = 0
    }
}
