import QtQuick
import QtQuick.Window
import "mock"

// Renders the settings page at a given width and store preset to a picture.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports settings-shot.qml -- <width> <preset 0-2> <out.png>
// (presets as in settings-overlap.qml: default, custom sound, launcher prefix shown)
Window {
    id: win
    readonly property var args: Qt.application.arguments.slice(-3)
    readonly property int pageW: parseInt(args[0])
    width: pageW
    height: page.height
    visible: true
    color: "#1C1B1F"

    SettingsCase {
        id: page
        pageWidth: win.pageW
        preset: [
            {},
            {
                "sound": "custom"
            },
            {
                "noTrigger": false
            }
        ][parseInt(win.args[1])]
    }

    Timer {
        interval: 300
        running: true
        onTriggered: page.grabToImage(r => {
            r.saveToFile(args[2]);
            Qt.quit();
        })
    }
}
