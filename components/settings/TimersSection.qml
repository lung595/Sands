import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// The "Timers" section: how the launcher understands what is typed.
Column {
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

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        text: "Examples: timer 20 min · 1h30 · 25m pasta · 1:30 · half an hour · at 6:30pm · timer 14h30. French works too: une demi-heure · 12 min pâtes · à 18h30\nCommand line: dms ipc call smartTimer start \"12 min pasta\" (also: toggle, stop, add 5, list, clear, panel)"
    }
}
