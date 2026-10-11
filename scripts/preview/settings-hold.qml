import QtQuick
import QtQuick.Window
import "mock"
import "mock/Presets.js" as Presets
import qs.Common

// Safe-try scene: the settings page in a resizable window that stays open, made-up
// store, stand-in DMS widgets. Drag the window edge to see the rows wrap at any width.
// Usage (through outils/essai.sh): essai.sh Sands <commit> settings-hold.qml <mode, ignored>
Window {
    width: 404
    height: 700
    visible: true
    color: Theme.surface

    Flickable {
        anchors.fill: parent
        contentHeight: page.height
        clip: true

        SettingsCase {
            id: page
            pageWidth: parent.width
            preset: Presets.list[0]
        }
    }
}
