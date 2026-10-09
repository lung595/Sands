import QtQuick

// Damped hover: `open` turns on after 120 ms and only off 450 ms after the
// pointer leaves. Without it, the notch re-centering while widening made the
// pointer enter/leave in a loop (flicker). Size it to the area to watch.
Item {
    id: dwell

    property bool open: false

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                hoverOut.stop();
                hoverIn.restart();
            } else {
                hoverIn.stop();
                hoverOut.restart();
            }
        }
    }

    Timer {
        id: hoverIn
        interval: 120
        onTriggered: dwell.open = true
    }

    Timer {
        id: hoverOut
        interval: 450
        onTriggered: dwell.open = false
    }
}
