import QtQuick
import QtQuick.Window
import qs.Common
import "mock"
import "../../components/launcher"
import "../../components/launcher/Section.js" as Section

// Renders the Timers row of Spotlight (live launcher section) as DMS lays it
// out: equal cards of at least 180 px, the row as high as its highest card.
// Made-up timers on a fixed clock. Variants:
//   one        one running timer, the whole width
//   four       4 timers and the "+N" card (6 timers)
//   ringing    a ringing card, selected, next to a running one
//   expanded   one open card, wide, with "Other timers"
//   narrow     an open card sharing the row with two others
//   ringing-open  an open ringing card: Stop, snooze, restart
//   favourites no timer: the favourites alone
//   stopped    "Stopped · Undo" next to a running card
//   all        every variant above, one under the other (default)
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports launcher-section.qml -- <out.png> [variant] [light] [reduce]
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property int argBase: args.indexOf("--") + 1
    readonly property string out: args[argBase]
    readonly property string variant: args.length > argBase + 1 && ["light", "reduce"].indexOf(args[argBase + 1]) < 0 ? args[argBase + 1] : "all"
    readonly property var variants: variant === "all" ? ["one", "four", "ringing", "favourites", "stopped", "expanded", "narrow", "ringing-open"] : [variant]

    width: 640 + 2 * Theme.spacingM
    height: col.height + 2 * Theme.spacingM
    visible: true
    color: Theme.surface

    readonly property var specs: ({
            "one": [["running", "Pâtes", 900000, 754000, 0]],
            // Typed in lower case, as from the IPC: the cards still write « Thé »
            "four": [["running", "thé", 300000, 250000, 1], ["running", "pâtes", 900000, 754000, 0], ["paused", "linge", 3600000, 1860000, 2], ["running", "four", 2700000, 1860000, 3], ["running", "Œufs", 420000, 400000, 4], ["running", "Pain", 2400000, 2200000, 5]],
            "ringing": [["ringing", "Pâtes", 600000, 0, 0], ["running", "Thé", 300000, 190000, 1]],
            "favourites": [],
            "stopped": [["running", "Thé", 300000, 190000, 1]],
            "expanded": [["running", "Pâtes", 900000, 754000, 0], ["running", "Thé", 300000, 250000, 1], ["paused", "Linge", 3600000, 1860000, 2], ["running", "Four", 2700000, 1860000, 3]],
            "narrow": [["running", "Pâtes", 900000, 754000, 0], ["running", "Thé", 300000, 250000, 1], ["paused", "Linge", 3600000, 1860000, 2]],
            "ringing-open": [["ringing", "Pâtes", 600000, 0, 0]]
        })
    readonly property var favourites: [
        {
            name: "Pâtes",
            ms: 600000,
            duration: "10 min"
        },
        {
            name: "Café",
            ms: 240000,
            duration: "4 min"
        },
        {
            name: "Linge",
            ms: 3600000,
            duration: "1 h"
        }
    ]

    Rectangle {
        id: shot
        width: win.width
        height: win.height
        color: Theme.surface

    Column {
        id: col
        x: Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingL

        Repeater {
            model: win.variants

            Item {
                id: scene
                required property string modelData
                width: 640
                height: strip.height

                FakeDaemon {
                    id: fake
                    Component.onCompleted: {
                        load(win.specs[scene.modelData] || []);
                        // The ringing one rang 42 s ago
                        now = base + 42000;
                    }
                }

                readonly property var items: {
                    const removed = scene.modelData === "stopped" ? [
                        {
                            timer: {
                                id: 9,
                                state: "running",
                                label: "Pâtes",
                                kind: "duration",
                                total: 600000,
                                endAt: fake.base + 300000,
                                remaining: 0,
                                finishedAt: 0
                            },
                            at: fake.base
                        }
                    ] : [];
                    return Section.build({
                        timers: fake.timers,
                        favourites: scene.modelData === "one" ? [] : win.favourites,
                        query: "",
                        trigger: "",
                        settings: {
                            section: true,
                            duringSearch: true,
                            favourites: true
                        },
                        prev: scene.modelData === "stopped" ? [
                            {
                                id: 9,
                                state: "running"
                            },
                            {
                                id: 1,
                                state: "running"
                            }
                        ] : [],
                        removed: removed,
                        now: fake.base + 1000
                    }).items;
                }
                readonly property string openId: (scene.modelData === "expanded" || scene.modelData === "narrow" || scene.modelData === "ringing-open") && items.length > 0 ? items[0].id : ""
                readonly property var shown: scene.modelData === "expanded" || scene.modelData === "ringing-open" ? items.slice(0, 1) : items

                Row {
                    id: strip
                    height: {
                        let h = 0;
                        for (let i = 0; i < cards.count; i++)
                            h = Math.max(h, cards.itemAt(i) ? cards.itemAt(i).implicitHeight : 0);
                        return h;
                    }
                    Repeater {
                        id: cards
                        model: scene.shown
                        SectionCard {
                            required property var modelData
                            required property int index
                            width: Math.max(640 / scene.shown.length, 180)
                            height: strip.height
                            daemon: fake
                            lang: "fr"
                            launcherItem: ({
                                    id: "live:smartTimer:" + modelData.id,
                                    name: modelData.name,
                                    data: modelData
                                })
                            selected: index === 0 && scene.modelData !== "favourites"
                            expanded: modelData.id === scene.openId
                        }
                    }
                }
            }
        }
    }

    }

    Timer {
        interval: 600
        running: true
        onTriggered: shot.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
