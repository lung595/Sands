import QtQuick
import qs.Common
import qs.Widgets
import "../../../../../../components/settings/SettingHost.js" as SettingHost

// Layout stand-in for the DMS SelectionSetting (Modules/Plugins/SelectionSetting.qml):
// a labelled DankDropdown, label column left and 200 px list right. Saving is left out.
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    property string value: defaultValue
    // Unused here, but the shared loader marks it
    property bool ready: false

    width: parent.width

    // Reads the stored value like the DMS row, so the other stores show up
    Component.onCompleted: Qt.callLater(() => SettingHost.load(root))
    spacing: Theme.spacingS

    DankDropdown {
        width: parent.width
        text: root.label
        description: root.description
        currentValue: root.value
        options: root.options.map(o => o.label || o)
    }
}
