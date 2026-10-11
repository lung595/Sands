import QtQuick
import "SettingHost.js" as SettingHost

// A stored list or map (not a switch or a string): reads the saved value once
// the page is parented, and saves each assignment of `value` under its key.
// Assign a new object each time, never edit one in place.
Item {
    id: root

    required property string settingKey
    property var defaultValue: null
    property var value: defaultValue
    // Set once the saved value is read, so the read itself is never written back
    property bool ready: false

    visible: false
    width: 0
    height: 0

    Component.onCompleted: Qt.callLater(() => SettingHost.load(root))
    onValueChanged: SettingHost.save(root)
}
