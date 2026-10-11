import QtQuick
import qs.Common
import qs.Widgets
import "../../../../../../components/settings/SettingHost.js" as SettingHost

// Layout stand-in for the DMS ToggleSetting (Modules/Plugins/ToggleSetting.qml): a Row
// whose title has no width and no wrapping. Kept faithful on purpose, it is the defect
// the overlap test must catch when a page still uses it. Saving is left out.
Row {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    property bool value: defaultValue
    // Unused here, but the shared loader marks it
    property bool ready: false

    width: parent.width

    // Reads the stored value like the DMS row, so the other stores show up
    Component.onCompleted: Qt.callLater(() => SettingHost.load(root))
    spacing: Theme.spacingM

    Column {
        width: parent.width - toggle.width - Theme.spacingM
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            text: root.label
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.description !== ""
        }
    }

    DankToggle {
        id: toggle
        anchors.verticalCenter: parent.verticalCenter
        checked: root.value
    }
}
