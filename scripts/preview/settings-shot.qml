import QtQuick
import QtQuick.Window
import "mock"

// Renders the settings page at 260 px (narrowest real width) to a picture.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports settings-shot.qml -- <out.png>
Window {
    width: 260
    height: page.height
    visible: true
    color: "#1C1B1F"

    SettingsCase {
        id: page
        pageWidth: 260
        preset: ({})
    }

    Timer {
        interval: 300
        running: true
        onTriggered: page.grabToImage(r => {
            r.saveToFile(Qt.application.arguments[Qt.application.arguments.length - 1]);
            Qt.quit();
        })
    }
}
