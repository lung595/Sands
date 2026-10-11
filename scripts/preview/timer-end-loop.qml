import QtQuick
import QtQuick.Window
import "mock"
import "mock/Presets.js" as Presets
import qs.Common

// Bench scene: the settings page stays open; when the timer-end row exists, a timer
// flips its mode and hovers it like a user changing the choice. On a base without the
// row it is just the open page, so A and B draw the same page.
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

    property var row: null
    property int n: 0

    function findRow(item) {
        for (const c of item.children) {
            if (c.objectName === "segments")
                return c.parent;
            const r = findRow(c);
            if (r)
                return r;
        }
        return null;
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (!row)
                row = findRow(page);
            if (row) {
                n++;
                row.mode = ["react", "sands", "alex"][n % 3];
            }
        }
    }
}
