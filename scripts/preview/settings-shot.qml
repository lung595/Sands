import QtQuick
import QtQuick.Window
import "mock"
import "mock/Presets.js" as Presets
import qs.Common

// Renders the settings page at a given width and store preset to a picture.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports settings-shot.qml -- <width> <preset, see mock/Presets.js> <dark|light> <out.png> <query, may be empty>
// The theme word "focus" renders dark with the keyboard focus on the open rail entry (shows the ring).
// Extra first arguments: "section=help" opens that section, "report=copied" or "report=none"
// shows the "Copy report" row in that state.
// (the word "light" among the arguments switches the stand-in Theme to a light palette)
Window {
    id: win
    readonly property var args: Qt.application.arguments.slice(-5)
    readonly property int pageW: parseInt(args[0])
    width: pageW
    height: page.height
    visible: true
    color: Theme.surface

    SettingsCase {
        id: page
        pageWidth: win.pageW
        query: win.args[4]
        preset: Presets.list[parseInt(win.args[1])]
    }

    function openSection(item, id) {
        if (item.objectName === "settingsPage") {
            item.section = id;
            return true;
        }
        for (const c of item.children) {
            if (openSection(c, id))
                return true;
        }
        return false;
    }

    function focusOpenEntry(item) {
        if (item.activeFocusOnTab && item.objectName === "control") {
            item.forceActiveFocus();
            return true;
        }
        for (const c of item.children) {
            if (focusOpenEntry(c))
                return true;
        }
        return false;
    }

    Component.onCompleted: {
        const report = Qt.application.arguments.find(a => a.indexOf("report=") === 0);
        if (report)
            Qt.callLater(() => page.page.daemon.reportClipboard.result = report.slice(7));
        const section = Qt.application.arguments.find(a => a.indexOf("section=") === 0);
        if (section)
            openSection(page, section.slice(8));
        if (args[2] === "focus")
            focusOpenEntry(page);
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
