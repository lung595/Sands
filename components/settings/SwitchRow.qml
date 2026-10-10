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
    height: implicitHeight

    function loadValue() {
        const host = SettingHost.find(root);
        if (!host)
            return;
        value = host.loadValue(settingKey, defaultValue);
        ready = true;
    }

    Component.onCompleted: Qt.callLater(loadValue)

    onValueChanged: {
        if (!ready)
            return;
        const host = SettingHost.find(root);
        if (host)
            host.saveValue(settingKey, value);
    }

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        StyledText {
            width: parent.width
            text: root.label
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        StyledText {
            width: parent.width
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            visible: root.description !== ""
        }
    }

    DankToggle {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.value
        onToggled: isChecked => root.value = isChecked
    }
}
