import QtQuick
import QtQuick.Window
import "../.."

// Bench scene for the real timer engine (TimerDaemon.qml), with mock
// processes (imports/Quickshell/Io/Process.qml): no sound and no
// notification leave the scene. It runs until stopped.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports daemon.qml -- <mode> /dev/null
//   idle   engine loaded, no timer (nothing should run)
//   run    one 1 h timer (the ticker only)
//   cycle  every 12 s: a 4 s timer with tick and notify on, its final
//          ticks, the ringing loop (player 1 s, gap 450 ms), then stop
Window {
    id: win

    readonly property string mode: Qt.application.arguments[Qt.application.arguments.length - 2]
    readonly property var settings: mode === "cycle" ? {
        "tick": true,
        "notify": true
    } : {}

    width: 16
    height: 16
    visible: true

    TimerDaemon {
        id: daemon

        pluginService: QtObject {
            function loadPluginData(id, key, fallback) {
                return win.settings[key] !== undefined ? win.settings[key] : fallback;
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

    Timer {
        interval: 12000
        running: win.mode === "cycle"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            daemon.clear();
            daemon.start(4000, "Bench", "duration", 0, false);
        }
    }

    Component.onCompleted: if (mode === "run")
        daemon.start(3600000, "Bench", "duration", 0, false)
}
