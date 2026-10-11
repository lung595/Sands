import QtQuick
import qs.Common
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
        anchors.rightMargin: Theme.spacingL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS
        visible: !root.compactMode
        StyledText {
            text: root.text
            width: parent.width
        }
        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            width: parent.width
            visible: root.description !== ""
        }
    }
    Rectangle {
        id: trigger
        objectName: "control"
        // Lets the overlap test see a value cut short, since it does not descend into controls
        readonly property bool truncated: valueText.truncated
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.compactMode ? parent.width : root.dropdownWidth
        height: 40
        radius: 8
        color: Theme.surfaceContainerHigh
        // The current value elides on the right, as DMS DankDropdown.qml:297 does
        StyledText {
            id: valueText
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentValue
            color: Theme.surfaceText
            wrapMode: Text.NoWrap
        }
        DankIcon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: Theme.iconSize
            color: Theme.surfaceText
        }
    }
}
