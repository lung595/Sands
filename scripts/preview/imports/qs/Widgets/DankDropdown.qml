import QtQuick
import qs.Widgets

// Preview stand-in for the DMS dropdown. Compact (no text, no description) it is
// `dropdownWidth` wide, like DMS; with a label it puts the label column on the
// left and the 200 px trigger on the right, which is what overlaps when narrow.
Item {
    id: root
    property string text: ""
    property string description: ""
    property string currentValue: ""
    property var options: []
    property int dropdownWidth: 200
    readonly property bool compactMode: text === "" && description === ""
    signal valueChanged(string newValue)
    width: compactMode ? dropdownWidth : parent.width
    implicitHeight: compactMode ? 40 : 60
    height: implicitHeight
    activeFocusOnTab: true
    Column {
        anchors.left: parent.left
        anchors.right: trigger.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        visible: !root.compactMode
        StyledText {
            text: root.text
            width: parent.width
        }
        StyledText {
            text: root.description
            font.pixelSize: 12
            width: parent.width
            visible: root.description !== ""
        }
    }
    Rectangle {
        id: trigger
        objectName: "control"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.compactMode ? parent.width : root.dropdownWidth
        height: 40
        radius: 8
        color: "#2B2930"
    }
}
