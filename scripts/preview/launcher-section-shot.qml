import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/launcher"
import "../../components/launcher/Section.js" as Section

// Renders the Timers row of Spotlight (live launcher section) from made-up
// timers: a ringing card (selected), a running one, a paused one, a "+N" card,
// and a row of favourites alone. Usage:
// QT_QPA_PLATFORM=offscreen qml-qt6 -I imports launcher-section-shot.qml -- <out.png> [light]
// ("light" among the arguments switches the stand-in Theme)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string out: args[args.indexOf("--") + 1]

    width: 5 * 184 + 2 * Theme.spacingM
    height: col.height + 2 * Theme.spacingM
    visible: true
    color: Theme.surface

    function timer(id, state, label, endAt) {
        return {
            id: id,
            label: label,
            kind: "duration",
            state: state,
            endAt: endAt,
            total: 60000,
            remaining: state === "paused" ? 30000 : 0,
            finishedAt: state === "ringing" ? 1 : 0
        };
    }

    readonly property var settings: ({
            section: true,
            duringSearch: true,
            favourites: true
        })
    readonly property var full: Section.build({
        timers: [timer(1, "running", "Tea", 9000), timer(2, "ringing", "Pasta", 1), timer(3, "paused", "Oven", 0), timer(4, "running", "", 5000), timer(5, "running", "Eggs", 20000), timer(6, "running", "Bread", 30000)],
        favourites: [],
        query: "",
        trigger: "",
        settings: settings
    }).items
    readonly property var favs: Section.build({
        timers: [timer(1, "running", "Tea", 9000)],
        favourites: [
            {
                name: "Pasta",
                ms: 600000,
                duration: "10 min"
            },
            {
                name: "Coffee",
                ms: 240000,
                duration: "4 min"
            },
            {
                name: "Laundry",
                ms: 3600000,
                duration: "1 h"
            }
        ],
        query: "",
        trigger: "",
        settings: settings
    }).items

    Column {
        id: col
        x: Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            Repeater {
                model: win.full
                SectionCard {
                    width: 184
                    height: implicitHeight
                    launcherItem: ({
                            id: "live:smartTimer:" + modelData.id,
                            name: modelData.name,
                            data: modelData
                        })
                    selected: index === 0
                }
            }
        }
        Row {
            Repeater {
                model: win.favs
                SectionCard {
                    width: 184
                    height: implicitHeight
                    launcherItem: ({
                            id: "live:smartTimer:" + modelData.id,
                            name: modelData.name,
                            data: modelData
                        })
                }
            }
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: col.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
