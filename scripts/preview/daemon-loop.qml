import QtQuick
import Quickshell

// Bench scene for the whole daemon (TimerDaemon.qml and every part it loads,
// the alert windows included), run by the real Quickshell offscreen. Started
// by daemon-loop.sh only: it stages the plugin next to this file and puts
// stand-ins for the sound players, notify-send, the clipboard tools, dms and
// niri first on PATH. It runs until stopped, and works on a revision that has
// no report service yet (the "report" mode then only says so).
// Modes (SANDS_BENCH_MODE):
//   idle    daemon loaded, no timer, nothing asked (nothing should run)
//   run     one 1 h timer (the ticker only)
//   report  every 12 s: one anonymous report asked as the IPC command does
//           (two CPU readings 1 s apart, then the real probes), taken once built
ShellRoot {
    id: bench

    readonly property string mode: Quickshell.env("SANDS_BENCH_MODE") || "idle"
    readonly property int reportEveryMs: 12000
    readonly property int oneHourMs: 3600000
    property int built: 0

    TimerDaemon {
        id: daemon

        pluginService: QtObject {
            function loadPluginData(id, key, fallback) {
                return fallback;
            }
            function savePluginData(id, key, value) {
            }
            function loadPluginState(id, key, fallback) {
                return fallback;
            }
            function savePluginState(id, key, value) {
            }
        }
    }

    Connections {
        target: daemon.report ?? null
        function onBuilt(text, via) {
            bench.built++;
            console.warn("sands-bench report " + bench.built + ": " + text.length + " characters");
        }
    }

    Timer {
        interval: bench.reportEveryMs
        running: bench.mode === "report"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!daemon.report) {
                console.warn("sands-bench no report service on this revision");
                stop();
                return;
            }
            daemon.report.takeReport();
            daemon.report.request("ipc");
        }
    }

    // console.log does not reach the terminal of a bench: the start-up
    // measure waits for this line
    Component.onCompleted: {
        if (mode === "run")
            daemon.start(oneHourMs, "Bench", "duration", 0, false);
        console.warn("sands-bench ready " + mode);
    }
}
