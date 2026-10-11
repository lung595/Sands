import QtQuick
import qs.Common
import qs.Widgets

// A text link with the states a button needs: hover background, pressed
// scale (none in Reduce motion), a focus ring and keyboard activation.
Item {
    id: root

    required property string caption
    property color textColor: Theme.surfaceVariantText
    property bool underline: false
    property real pixelSize: Theme.fontSizeSmall
    property bool reducedMotion: false
    signal clicked

    activeFocusOnTab: enabled
    implicitWidth: label.implicitWidth + Theme.spacingM * 2
    implicitHeight: 44
    scale: area.pressed && !reducedMotion ? 0.97 : 1
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        radius: 12
        color: area.containsMouse ? Theme.surfaceContainerHighest : "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.primary
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.caption
        font.pixelSize: root.pixelSize
        font.underline: root.underline
        color: root.textColor
        wrapMode: Text.NoWrap
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
