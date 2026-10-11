import QtQuick
import qs.Common
import qs.Widgets

// The "Help" section: read-only examples of what the launcher understands.
Column {
    // Found by search under this key, so a pick has a block to highlight
    readonly property string settingKey: "examples"

    width: parent.width
    spacing: Theme.spacingM

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        text: "Examples: timer 20 min · 1h30 · 25m pasta · 1:30 · half an hour · at 6:30pm · timer 14h30. French works too: une demi-heure · 12 min pâtes · à 18h30\nCommand line: dms ipc call smartTimer start \"12 min pasta\" (also: toggle, stop, add 5, list, clear, panel)"
    }
}
