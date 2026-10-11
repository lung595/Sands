import QtQuick
import QtQuick.Window
import "mock"
import "mock/Presets.js" as Presets
import qs.Common

// Bench scene: drives the settings page itself, in a loop, on mock data.
// Modes (first argument): idle (page closed), open (build and destroy the page),
// still (page open, nothing happens), type (types and clears a query),
// switch (walks the sections; ignored by builds that have none).
Window {
    id: win
    width: 404
    height: 700
    visible: true
    color: Theme.surface

    readonly property string mode: Qt.application.arguments.length > 1 ? Qt.application.arguments[Qt.application.arguments.length - 2] : "idle"
    property int step: 0

    Loader {
        id: host
        anchors.fill: parent
        active: win.mode !== "idle" && win.mode !== "open"
        sourceComponent: Component {
            SettingsCase {
                pageWidth: win.width
                preset: Presets.list[0]
            }
        }
    }
    Loader {
        id: opener
        anchors.fill: parent
        active: false
        sourceComponent: host.sourceComponent
    }

    Timer {
        interval: win.mode === "type" ? 120 : 700
        running: win.mode === "open" || win.mode === "type" || win.mode === "switch"
        repeat: true
        onTriggered: {
            win.step++;
            if (win.mode === "open") {
                opener.active = !opener.active;
            } else if (win.mode === "type") {
                const q = "volume snooze alerts";
                const n = win.step % (q.length + 6);
                host.item.query = n > q.length ? "" : q.slice(0, n);
            } else {
                const p = host.item.page;
                if (p.section === undefined)
                    return;
                const ids = ["timers", "alerts", "appearance", "help"];
                p.section = ids[win.step % ids.length];
            }
        }
    }
}
