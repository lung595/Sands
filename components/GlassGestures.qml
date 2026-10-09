import QtQuick

// Gestures on the hourglass: click = just a wild animation (it never
// changes the timer: restart is the button's job), wheel = ±1 min,
// swipe / horizontal wheel = another timer. Only reports; the panel acts.
MouseArea {
    id: root

    // Without a timer to act on, the wheel does nothing.
    property bool active: true

    signal tapped
    // +1 = next timer, -1 = previous
    signal switchTimer(int step)
    // +1 / -1 minute
    signal addMinute(int step)

    property real pressX: 0
    property bool swiped: false
    property real accX: 0
    property real accY: 0

    cursorShape: Qt.PointingHandCursor

    onPressed: m => {
        pressX = m.x;
        swiped = false;
    }
    onPositionChanged: m => {
        if (!swiped && Math.abs(m.x - pressX) > 40) {
            swiped = true;
            switchTimer(m.x < pressX ? 1 : -1);
        }
    }
    onClicked: {
        if (!swiped)
            tapped();
    }
    onWheel: w => {
        if (!active)
            return;
        if (Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y)) {
            accX += w.angleDelta.x;
            if (Math.abs(accX) >= 120) {
                switchTimer(accX < 0 ? 1 : -1);
                accX = 0;
            }
        } else {
            accY += w.angleDelta.y;
            while (Math.abs(accY) >= 120) {
                const step = accY > 0 ? 1 : -1;
                accY -= step * 120;
                addMinute(step);
            }
        }
        w.accepted = true;
    }
}
