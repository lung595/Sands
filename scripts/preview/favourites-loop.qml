import QtQuick
import QtQuick.Window
import qs.Common
import "../../components"
import "mock"

// Bench scene: the panel with made-up favourites; "closed" keeps it hidden,
// "open-loop" shows and hides it every 1.2 s, "click-loop" also starts the
// first pinned timer on each opening. Runs on revisions without favourites
// too (the pins are then ignored), so the base gives the reference.
// Usage: qml-qt6 -I imports favourites-loop.qml -- closed|open-loop|click-loop /dev/null
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.indexOf("--") + 1]

    function findPins(item) {
        for (const c of item.data) {
            if (c.startPin)
                return c;
            const r = findPins(c);
            if (r)
                return r;
        }
        return null;
    }

    width: 340
    height: 760
    visible: true
    color: Theme.surface

    FakeDaemon {
        id: fake
        favourites: [["work", 41, 25], ["tea", 23, 4], ["pasta", 17, 11]].map(a => ({
                    "name": a[0],
                    "count": a[1],
                    "ms": a[2] * 60000
                }))
    }

    Loader {
        id: view
        width: win.width
        sourceComponent: TimerPanelContent {
            daemon: fake
            shown: false
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: win.mode !== "closed" && view.status === Loader.Ready
        onTriggered: {
            const open = !view.item.shown;
            view.item.shown = open;
            if (open && win.mode === "click-loop") {
                const f = win.findPins(view.item);
                if (f)
                    f.startPin(0);
            }
        }
    }
}
