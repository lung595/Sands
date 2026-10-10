import QtQuick
import qs.Common
import qs.Widgets

// Layout stand-in for the DMS SelectionSetting (Modules/Plugins/SelectionSetting.qml):
// a labelled DankDropdown, label column left and 200 px list right. Loading and saving
// are left out.
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    property string value: defaultValue

    width: parent.width
    spacing: Theme.spacingS

    DankDropdown {
        width: parent.width
        text: root.label
        description: root.description
        currentValue: root.value
        options: root.options.map(o => o.label || o)
    }
}
