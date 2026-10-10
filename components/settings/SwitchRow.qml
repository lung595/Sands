import QtQuick
import qs.Common
import qs.Widgets
import "SettingHost.js" as SettingHost

// A switch setting. The text takes what the switch leaves and wraps there, so
// at any width nothing is drawn under the switch (the DMS ToggleSetting gives its
// title no width, so a narrow page runs it under the control).
Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    property bool value: defaultValue
    // Set once the saved value is read, so the read itself is never written back
    property bool ready: false

    width: parent.width
    implicitHeight: Math.max(texts.implicitHeight, toggle.height)

    Component.onCompleted: Qt.callLater(() => SettingHost.load(root))
    onValueChanged: SettingHost.save(root)

    SettingLabel {
        id: texts
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        title: root.label
        description: root.description
    }

    DankToggle {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.value
        onToggled: isChecked => root.value = isChecked
    }
}
