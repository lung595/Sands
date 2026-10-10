import QtQuick
import qs.Common
import qs.Widgets

// DMS layout (the title has no width, as in Modules/Plugins/SliderSetting.qml): label, wrapped description, full-width slider.
Column {
    id: root
    required property string settingKey
    required property string label
    property string description: ""
    property int defaultValue: 0
    property int minimum: 0
    property int maximum: 100
    property string unit: ""
    property string leftIcon: ""
    property string rightIcon: ""
    width: parent.width
    spacing: 8
    StyledText {
        text: root.label
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
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
