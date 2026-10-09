import QtQuick
import QtQuick.Window
import qs.Common
import qs.Services
import "../../components"
import "mock"

// Offscreen renders of Sands with a made-up daemon and made-up timers.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports shot.qml -- <mode> <out.png>
// Modes:
//   pill-idle, pill-running, pill-label (right after a start), pill-done,
//   pill-4 (four timers), panel, panel-paused, panel-ringing, panel-4
//   (four 1 h timers), panel-toggle (pause and resume every 2 s, bench
//   only, with "-hold"), hourglass-running, hourglass-frozen, hourglass-ringing
// Suffixes: "-reduce" turns Reduce motion on (the sand and the float stand
// still, so the picture is the same on every run), "-hold" takes no picture and
// keeps running on the real clock (what banc-ab.sh and essai.sh want).
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property string rawMode: args[args.length - 2]
    readonly property string out: args[args.length - 1]
    readonly property bool hold: rawMode.endsWith("-hold")
    readonly property bool reduce: rawMode.indexOf("-reduce") >= 0
    readonly property string mode: rawMode.replace("-hold", "").replace("-reduce", "")
    readonly property string kind: mode.split("-")[0]

    // [state, label, total ms, ms left, hue]; Mm are minutes, Hh hours
    readonly property int mm: 60000
    readonly property var scenes: ({
            "pill-idle": [],
            "pill-running": [["running", "Pasta", 20 * mm, 12 * mm + 34000, 0]],
            "pill-label": [["running", "Pasta", 20 * mm, 12 * mm + 34000, 0]],
            "pill-done": [["ringing", "Tea", 4 * mm, 0, 0]],
            "pill-4": [["running", "Run", 60 * mm, 59 * mm, 0], ["running", "Bake", 60 * mm, 59 * mm + 1000, 1], ["running", "Read", 60 * mm, 59 * mm + 2000, 2], ["running", "Laundry", 60 * mm, 59 * mm + 3000, 3]],
            "panel": [["running", "Pasta", 20 * mm, 12 * mm + 34000, 0], ["running", "Laundry", 45 * mm, 31 * mm, 1]],
            "panel-paused": [["paused", "Pasta", 20 * mm, 12 * mm + 34000, 0]],
            "panel-toggle": [["paused", "Pasta", 20 * mm, 12 * mm + 34000, 0]],
            "panel-ringing": [["ringing", "Tea", 4 * mm, 0, 0]],
            "panel-4": [["running", "Run", 60 * mm, 59 * mm, 0], ["running", "Bake", 60 * mm, 59 * mm + 1000, 1], ["running", "Read", 60 * mm, 59 * mm + 2000, 2], ["running", "Laundry", 60 * mm, 59 * mm + 3000, 3]],
            "hourglass-running": [],
            "hourglass-frozen": [],
            "hourglass-ringing": []
        })

    width: kind === "pill" ? 360 : (kind === "hourglass" ? 300 : 400)
    // The panel is as tall as its content, like the popout
    height: kind === "pill" ? 80 : (kind === "hourglass" ? 300 : panelLoader.height)
    visible: true

    // A window's own colour is not part of what grabToImage takes
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    FakeDaemon {
        id: daemon
        live: win.hold
    }

    property bool ready: false
    Component.onCompleted: {
        SettingsData.reduceMotion = win.reduce;
        daemon.load(win.scenes[win.mode] ?? []);
        PluginService.pluginDaemonInstances = {
            "smartTimer": daemon
        };
        ready = true;
    }

    Loader {
        id: host
        active: win.ready && win.kind !== "hourglass"
        source: "../../TimerWidget.qml"
        // Untyped on purpose: the host stand-in is only known at run time
        readonly property var widget: item
    }

    // The bar: a strip at the height of a default DMS bar, the pill inside.
    Rectangle {
        visible: win.kind === "pill"
        anchors.centerIn: parent
        width: parent.width - 40
        height: 40
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Loader {
            id: pill
            anchors.centerIn: parent
            // Like the bar: no timer, no pill
            active: host.item !== null && win.kind === "pill" && daemon.hasTimers
            sourceComponent: host.widget ? host.widget.horizontalBarPill : null
            onLoaded: if (win.mode === "pill-label")
                daemon.timerStarted(1)
        }
    }

    // The popout: the panel and the note, as the widget lays them out.
    Rectangle {
        visible: win.kind === "panel"
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: panelLoader.height
        color: Theme.surfaceContainer

        Loader {
            id: panelLoader
            width: parent.width
            active: host.item !== null && win.kind === "panel"
            sourceComponent: host.widget ? host.widget.popoutContent : null
        }
    }

    Hourglass {
        visible: win.kind === "hourglass"
        anchors.fill: parent
        progress: 0.55
        paused: win.mode === "hourglass-frozen"
        ringing: win.mode === "hourglass-ringing"
        frost: paused ? 1 : 0
        reducedMotion: win.reduce
        sandColor: ringing ? Theme.error : Theme.primary
        glassColor: Theme.surfaceText
        capColor: Theme.surfaceContainerHighest
        frostColor: Qt.hsla(0.56, 0.85, Math.max(0.45, Math.min(0.88, Theme.surfaceText.hslLightness)), 1)
        shadowColor: "black"
    }

    // The pause/resume action in a loop: the frost Loaders come and go
    Timer {
        interval: 2000
        repeat: true
        running: win.ready && win.hold && win.mode === "panel-toggle"
        onTriggered: daemon.flip(1)
    }

    // Long enough for the 0.9 s freeze and the pill's 120 ms hover to land,
    // short enough for the 2.2 s start flash of "pill-label" to be on.
    Timer {
        interval: 1300
        running: win.ready && !win.hold
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
