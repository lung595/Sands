import QtQuick

// Wheel: ±1 min (on a ringing timer, up = +1 min).
// Middle click: cancel (or stop the alarm). Left and right go to the BasePill below.
MouseArea {
    id: area

    property var daemon: null
    // Timer shown by the pill, or null.
    property var target: null
    property bool ringing: false

    property real acc: 0

    acceptedButtons: Qt.MiddleButton

    onClicked: {
        if (!area.daemon || !area.target)
            return;
        if (area.ringing)
            area.daemon.dismissRinging();
        else
            area.daemon.remove(area.target.id);
    }
    onWheel: wheel => {
        if (!area.daemon || !area.target)
            return;
        acc += wheel.angleDelta.y;
        while (Math.abs(acc) >= 120) {
            const step = acc > 0 ? 1 : -1;
            acc -= step * 120;
            if (step < 0 && area.ringing)
                continue;
            area.daemon.adjust(area.target.id, step * 60000);
        }
        wheel.accepted = true;
    }
}
