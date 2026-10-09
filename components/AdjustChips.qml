import QtQuick
import qs.Common

// −1 / +1 / +5 minutes on the shown timer.
Row {
    id: root

    required property var daemon
    required property var timer
    required property string timerState
    required property real remaining

    spacing: Theme.spacingS

    Chip {
        // Never takes a timer below its last minute
        visible: root.timerState !== "ringing" && root.remaining > 61000
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
