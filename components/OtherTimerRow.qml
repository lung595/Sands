import QtQuick
import qs.Common
import qs.Widgets
import "../TimeParser.js" as TP

// One line of the list of the other timers: ring, name, time left, actions.
Rectangle {
    id: root

    required property var daemon
    required property int timerId

    // Click on the line: show this timer large
    signal picked(int id)

    readonly property var tm: daemon ? daemon.find(timerId) : null
    readonly property string lst: tm ? tm.state : ""
    readonly property real lrem: (daemon && tm) ? daemon.remainingOf(tm, daemon.now) : 0

    height: 48
    radius: Theme.cornerRadius
    color: lineMouse.containsMouse ? Theme.surfaceTextHover : "transparent"

    MouseArea {
        id: lineMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(root.timerId)
    }

    ProgressRing {
        id: miniRing
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        thickness: 3
        progress: root.daemon ? root.daemon.progressOf(root.tm) : 0
        color: root.lst === "ringing" ? Theme.error : (root.lst === "paused" ? Theme.surfaceVariantText : (root.daemon && root.tm ? root.daemon.colorFor(root.tm) : Theme.primary))
        trackColor: Theme.surfaceContainerHighest
    }

    StyledText {
        anchors.left: miniRing.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: lineTime.left
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        text: root.daemon ? root.daemon.displayLabel(root.tm) : ""
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    StyledText {
        id: lineTime
        anchors.right: lineActions.left
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        text: TP.formatClock(root.lrem)
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
        color: root.lst === "ringing" ? Theme.error : (root.lst === "paused" ? Theme.surfaceVariantText : Theme.surfaceText)
    }

    Row {
        id: lineActions
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        DankActionButton {
            buttonSize: 36
            iconName: root.lst === "running" ? "pause" : (root.lst === "paused" ? "play_arrow" : "stop")
            iconColor: root.lst === "ringing" ? Theme.error : Theme.surfaceText
            onClicked: root.daemon.toggle(root.timerId)
        }
        DankActionButton {
            buttonSize: 36
            iconName: "close"
            iconColor: Theme.surfaceVariantText
            onClicked: root.daemon.remove(root.timerId)
        }
    }
}
