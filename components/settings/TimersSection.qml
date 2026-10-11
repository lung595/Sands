import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// The "Timers" section: how the launcher understands what is typed.
Column {
    id: root

    // The daemon, for the guide link of the end actions
    required property var daemon

    width: parent.width
    spacing: Theme.spacingM

    SwitchRow {
        id: noTriggerSetting
        settingKey: "noTrigger"
        label: "Automatic detection"
        description: "Understands “timer 20 min”, “25m pasta” or “at 6pm” without a prefix. Off: type the prefix below first."
        defaultValue: true
    }

    StringSetting {
        visible: !noTriggerSetting.value
        settingKey: "trigger"
        label: "Prefix"
        description: "Example with “timer”: “timer 20 min”"
        placeholder: "timer"
        defaultValue: "timer"
    }

    EndActionsSection {
        daemon: root.daemon
    }
}
