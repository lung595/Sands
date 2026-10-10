import QtQuick

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
        color: root.checked ? "#D0BCFF" : "#49454F"
    }
}
