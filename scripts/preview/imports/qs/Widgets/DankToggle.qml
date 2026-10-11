import QtQuick
import qs.Common

// Preview stand-in with the DMS size (52 x 30 track, no text) and its signals.
Item {
    id: root
    objectName: "control"
    property bool checked: false
    signal toggled(bool checked)
    width: 52
    height: 30
    activeFocusOnTab: true
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
    }
}
