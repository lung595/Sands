import QtQuick
import qs.Common
import qs.Widgets
import "SettingHost.js" as SettingHost

// A list setting: title and description wrap on top, the list takes the full
// row below. The DMS SelectionSetting puts its 200 px list beside the title, which
// crushes the title to a few pixels on a narrow page.
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    // [{label, value}], as the DMS SelectionSetting takes them
    required property var options
    property string defaultValue: ""
    property string value: defaultValue
    // Set once the saved value is read, so the read itself is never written back
    property bool ready: false

    readonly property string currentLabel: {
        const hit = options.find(o => o.value === value);
        return hit ? hit.label : value;
    }

    width: parent.width
    spacing: Theme.spacingS

    Component.onCompleted: Qt.callLater(() => SettingHost.load(root))
    onValueChanged: SettingHost.save(root)

    SettingLabel {
        width: parent.width
        title: root.label
        description: root.description
    }

    // No text of its own: that is what makes DMS draw it as the bare list
    DankDropdown {
        dropdownWidth: root.width
        currentValue: root.currentLabel
        options: root.options.map(o => o.label)
        onValueChanged: label => {
            const hit = root.options.find(o => o.label === label);
            root.value = hit ? hit.value : label;
        }
    }
}
