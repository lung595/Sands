import QtQuick
import qs.Common
import "../TimeParser.js" as TP

// Cancel · pause/resume · restart, or Stop · restart once finished.
Item {
    id: root

    required property var daemon
    required property var timer
    required property string timerState
    // Color of the displayed timer, and a text color readable on it
    required property color accent
    required property color accentText

    height: 64

    // Running / paused: cancel · pause/resume · restart.
    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXL
        visible: root.timerState !== "ringing"

        RoundButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "close"
            tooltip: "Cancel timer"
            onClicked: root.daemon.remove(root.timer.id)
        }

        RoundButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 64
            filled: true
            // Color of the displayed timer; dark or light text depending on the background.
            accent: root.accent
            accentText: root.accentText
            iconName: root.timerState === "paused" ? "play_arrow" : "pause"
            tooltip: root.timerState === "paused" ? "Resume" : "Pause"
            onClicked: root.daemon.toggle(root.timer.id)
        }

        RoundButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "replay"
            tooltip: "Restart (" + (root.timer ? TP.formatHuman(root.timer.total) : "") + ")"
            onClicked: root.daemon.restart(root.timer.id)
        }
    }

    // Finished: one obvious action, and "restart" next to it.
    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingM
        visible: root.timerState === "ringing"

        StopButton {
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.daemon.dismiss(root.timer.id)
        }

        RoundButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 56
            iconName: "replay"
            tooltip: "Restart " + (root.timer ? TP.formatHuman(root.timer.total) : "")
            onClicked: root.daemon.restart(root.timer.id)
        }
    }
}
