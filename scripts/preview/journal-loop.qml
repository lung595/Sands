import QtQuick
import QtQuick.Window
import qs.Common
import "../../components"
import "mock"

// Bench scene: the panel with made-up weeks; "closed" leaves the journal shut,
// "<look>-loop" opens and closes it every 1.2 s (the rise lasts under 0.5 s).
// Runs on revisions without a journal too (the property is then ignored), so
// the base gives the idle reference.
// Usage: qml-qt6 -I imports journal-loop.qml -- closed|strata-loop|threads-loop /dev/null
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.indexOf("--") + 1]

    width: 340
    height: 760
    visible: true
    color: Theme.surface

    FakeDaemon {
        id: fake
        week: [["work", 360], ["reading", 150], ["laundry", 75], ["pasta", 48], ["tea", 12]].map(a => ({
                    "name": a[0],
                    "ms": a[1] * 60000
                }))
    }

    Loader {
        id: view
        width: win.width
        sourceComponent: TimerPanelContent {
            daemon: fake
        }
        onLoaded: if (win.mode !== "closed" && "journalLook" in item)
            item.journalLook = win.mode.split("-")[0]
    }

    Timer {
        interval: 1200
        repeat: true
        running: win.mode !== "closed" && view.status === Loader.Ready
        onTriggered: if ("journalOpen" in view.item)
            view.item.journalOpen = !view.item.journalOpen
    }
}
