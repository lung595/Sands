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

    spacing: Theme.spacingS

    Chip {
        // Stops at 0:10 (the daemon's floor): shown while there is more
        visible: root.timerState !== "ringing" && root.remaining > Lifecycle.FLOOR_MS
        text: "−1 min"
        onClicked: root.daemon.adjust(root.timer.id, -60000)
    }
    Chip {
        text: "+1 min"
        onClicked: root.daemon.adjust(root.timer.id, 60000)
    }
    Chip {
        text: "+5 min"
        onClicked: root.daemon.adjust(root.timer.id, 300000)
    }
}
