import QtQuick
import qs.Common
import qs.Widgets
import ".."

// A round icon-only button of a launcher card: tooltip on hover, a name for
// screen readers, Tab reaches it and Enter presses it (Space goes up to the
// card, where it pauses the timer).
Rectangle {
    id: root

    property string iconName: ""
    property string tooltip: ""
    property bool filled: false
    property color accent: Theme.primary
    // On a filled button: dark on a light colour, white on a dark one
    property color iconColor: filled ? (accent.hslLightness > 0.6 ? "#1D1B20" : "#FFFFFF") : Theme.surfaceText
    property int size: 36

    signal clicked

    width: size
    height: size
    radius: size / 2
    activeFocusOnTab: visible
    color: filled ? (mouse.containsMouse ? Qt.lighter(accent, 1.08) : accent) : (mouse.pressed ? Theme.surfaceContainerHighest : (mouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.8) : "transparent"))
    scale: mouse.pressed ? 0.92 : 1

    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Accessible.onPressAction: root.clicked()

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked();
            event.accepted = true;
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: Math.round(root.size * 0.56)
        filled: root.filled
        color: root.iconColor
    }

    FocusRing {
        anchors.margins: -2
        radius: width / 2
        visible: root.activeFocus
        border.color: Theme.primary
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    DankTooltipV2 {
        id: tip
    }

    Timer {
        interval: 600
        running: mouse.containsMouse && root.tooltip !== ""
        onTriggered: tip.show(root.tooltip, root, 0, 0, "bottom")
    }

    Connections {
        target: mouse
        function onContainsMouseChanged() {
            if (!mouse.containsMouse)
                tip.hide();
        }
    }
}
