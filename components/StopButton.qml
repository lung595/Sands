import QtQuick
import qs.Common
import qs.Widgets

// The one obvious action once a timer has finished.
Rectangle {
    id: root

    signal clicked

    width: 168
    height: 56
    radius: height / 2
    color: mouse.pressed ? Qt.darker(Theme.error, 1.12) : (mouse.containsMouse ? Qt.lighter(Theme.error, 1.08) : Theme.error)
    scale: mouse.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 120
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "stop"
            filled: true
            size: Theme.iconSize
            color: Theme.onError
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Stop"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: Theme.onError
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
