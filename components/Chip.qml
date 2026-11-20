import QtQuick
import qs.Common
import qs.Widgets

// Secondary action chip: « +1 min », « Restart »…
Rectangle {
    id: root

    property string text: ""
    property string iconName: ""

    signal clicked

    implicitWidth: row.implicitWidth + Theme.spacingM * 2
    implicitHeight: 36
    radius: height / 2
    color: mouse.pressed ? Theme.surfaceContainerHighest : (mouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.8) : Theme.surfaceContainerHigh)
    scale: mouse.pressed ? 0.96 : 1
    opacity: enabled ? 1 : 0.35

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            visible: root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            size: Theme.iconSizeSmall
            color: Theme.surfaceText
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            font.features: {
                "tnum": 1
            }
            color: Theme.surfaceText
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Keyboard, where a chip is in the Tab chain (activeFocusOnTab, the
    // launcher card): Enter presses it, a ring shows the focus. Space is left
    // to the card (it pauses the timer)
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked();
            event.accepted = true;
        }
    }

    FocusRing {
        anchors.margins: -2
        radius: height / 2
        visible: root.activeFocus
        border.color: Theme.primary
    }
}
