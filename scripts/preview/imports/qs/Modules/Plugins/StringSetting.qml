import QtQuick
import qs.Widgets

// DMS layout: label, wrapped description, full-width field.
Column {
    id: root
    required property string settingKey
    required property string label
    property string description: ""
    property string placeholder: ""
    property string defaultValue: ""
    width: parent.width
    spacing: 8
    StyledText {
        text: root.label
        width: parent.width
        wrapMode: Text.WordWrap
    }
    StyledText {
        text: root.description
        width: parent.width
        font.pixelSize: 12
        visible: root.description !== ""
    }
    Rectangle {
        objectName: "control"
        width: parent.width
        height: 40
        color: "#2B2930"
    }
}
