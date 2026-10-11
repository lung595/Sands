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
    spacing: Theme.spacingS
    StyledText {
        text: root.label
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
    }
    StyledText {
        text: root.description
        color: Theme.surfaceVariantText
        width: parent.width
        font.pixelSize: Theme.fontSizeSmall
        visible: root.description !== ""
    }
    Rectangle {
        objectName: "control"
        width: parent.width
        height: 40
        color: Theme.surfaceContainerHigh
    }
}
