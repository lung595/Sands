import QtQuick
import qs.Common
import qs.Widgets
import ".."
import "Card.js" as Card

// A mini-card of "Other timers" in an open card: small hourglass, name,
// time. A click makes it the open card.
Rectangle {
    id: root

    required property var daemon
    required property int timerId
    property bool animate: false

    signal picked(int id)

    readonly property var tm: daemon ? daemon.find(timerId) : null
    readonly property string tstate: tm ? tm.state : ""

    width: 156
    height: 44
    radius: Theme.cornerRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: tm ? daemon.displayLabel(tm) + " " + Card.clock(tm, daemon.now) : ""
    Accessible.onPressAction: root.picked(root.timerId)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.picked(root.timerId);
            event.accepted = true;
        }
    }

    MiniGlass {
        id: glass
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        size: 32
        daemon: root.daemon
        timer: root.tm
        animate: root.animate
        accent: root.daemon && root.tm ? root.daemon.colorFor(root.tm) : Theme.primary
    }

    DankIcon {
        id: pausedMark
        visible: root.tstate === "paused"
        anchors.left: glass.right
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        name: "pause"
        size: 14
        color: Theme.surfaceVariantText
    }

    StyledText {
        anchors.left: pausedMark.visible ? pausedMark.right : glass.right
        anchors.leftMargin: Theme.spacingXS
        anchors.right: time.left
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        text: root.daemon && root.tm ? root.daemon.displayLabel(root.tm) : ""
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    StyledText {
        id: time
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        text: root.tm ? Card.clock(root.tm, root.daemon.now) : ""
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
        color: root.tstate === "ringing" ? Theme.error : (root.tstate === "paused" ? Theme.surfaceVariantText : Theme.surfaceText)
    }

    FocusRing {
        anchors.margins: 0
        visible: root.activeFocus
        border.color: Theme.primary
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(root.timerId)
    }
}
