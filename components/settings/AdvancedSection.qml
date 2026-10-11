import QtQuick
import qs.Common
import qs.Widgets

// The "Advanced" section: what Sands keeps on this machine, and a way to erase it.
Column {
    id: root

    // The daemon that owns the history file; null while it is not loaded
    required property var daemon
    readonly property string settingKey: "eraseHistory"
    // Said once the history was erased, until the page is rebuilt
    property bool erased: false

    width: parent.width
    spacing: Theme.spacingM

    SettingLabel {
        width: parent.width
        title: "Erase history"
        description: root.erased ? "History erased. The journal and the favourites are empty." : "Empties the journal and the favourites at once. They live in one small file of Sands' own on this machine; nothing is sent anywhere."
    }

    DankButton {
        text: "Erase history"
        iconName: "delete"
        enabled: root.daemon !== null
        opacity: enabled ? 1 : 0.4
        onClicked: {
            root.daemon.eraseHistory();
            root.erased = true;
        }
    }
}
