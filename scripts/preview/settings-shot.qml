import QtQuick
import QtQuick.Window
import "mock"
import "mock/Presets.js" as Presets
import qs.Common

// Renders the settings page at a given width and store preset to a picture.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports settings-shot.qml -- <width> <preset, see mock/Presets.js> <dark|light> <out.png>
// (the word "light" among the arguments switches the stand-in Theme to a light palette)
Window {
    id: win
    readonly property var args: Qt.application.arguments.slice(-4)
    readonly property int pageW: parseInt(args[0])
    width: pageW
    height: page.height
    visible: true
    color: Theme.surface

    SettingsCase {
        id: page
        pageWidth: win.pageW
        preset: Presets.list[parseInt(win.args[1])]
    }

    Timer {
        interval: 300
        running: true
        onTriggered: page.grabToImage(r => {
            r.saveToFile(args[3]);
            Qt.quit();
        })
    }
}
