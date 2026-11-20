import QtQuick
import qs.Common
import "daemon/Lifecycle.js" as Lifecycle

// −1 / +1 / +5 minutes on the shown timer.
Row {
    id: root

    required property var daemon
    required property var timer
    required property string timerState
    required property real remaining
    // "+1" instead of "+1 min" (the launcher card, where room is short)
    property bool short: false
    // −1 shows while more than this is left (the panel: the daemon's 0:10
    // floor; the launcher card hides it under 1:01)
    property real minusFrom: Lifecycle.FLOOR_MS

    spacing: Theme.spacingS

    Chip {
        // Stops at 0:10 (the daemon's floor): shown while there is more
        visible: root.timerState !== "ringing" && root.remaining > root.minusFrom
        text: root.short ? "−1" : "−1 min"
        onClicked: root.daemon.adjust(root.timer.id, -60000)
    }
    Chip {
        text: root.short ? "+1" : "+1 min"
        onClicked: root.daemon.adjust(root.timer.id, 60000)
    }
    Chip {
        text: root.short ? "+5" : "+5 min"
        onClicked: root.daemon.adjust(root.timer.id, 300000)
    }
}
