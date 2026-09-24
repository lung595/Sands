import QtQuick
import qs.Common
import qs.Widgets

// Bouton rond à icône. `filled` : couleur d'accent (l'action principale).
Rectangle {
    id: root

    property string iconName: ""
    property bool filled: false
    property color accent: Theme.primary
    property color accentText: Theme.onPrimary
    property int size: 48
    property string tooltip: ""

    signal clicked

    width: size
    height: size
    radius: size / 2
    color: {
        if (filled)
            return mouse.pressed ? Qt.darker(accent, 1.12) : (mouse.containsMouse ? Qt.lighter(accent, 1.08) : accent);
        return mouse.pressed ? Theme.surfaceContainerHighest : (mouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.8) : Theme.surfaceContainerHigh);
    }
    scale: mouse.pressed ? 0.94 : 1
    opacity: enabled ? 1 : 0.35

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: Math.round(root.size * 0.46)
        filled: root.filled
        color: root.filled ? root.accentText : Theme.surfaceText
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
