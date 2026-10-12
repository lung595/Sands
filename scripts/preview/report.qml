import QtQuick
import QtQuick.Window
import "../../components/daemon"

// Bench scene for the report service alone (components/daemon/ReportService.qml),
// with mock processes and files (imports/Quickshell/Io): nothing is copied and
// no tool runs. It does not load the alert windows, so it needs no
// Quickshell.Wayland. It runs until stopped.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports report.qml -- <mode> /dev/null
//   idle   service loaded, nothing asked (nothing should run)
//   ipc    every 12 s: one anonymous report asked as the IPC command does
//          (two CPU readings 1 s apart, then the probes), taken once built
Window {
    id: win

    readonly property string mode: Qt.application.arguments[Qt.application.arguments.length - 2]
    property int built: 0

    width: 16
    height: 16
    visible: true

    ReportService {
        id: service
        engine: QtObject {
            property var timers: []
            function setting(key, fallback) {
                return fallback;
            }
        }
        onBuilt: (text, via) => {
            win.built++;
            console.log("report " + win.built + " built for " + via + ": " + text.length + " characters");
        }
    }

    Timer {
        interval: 12000
        running: win.mode === "ipc"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            service.takeReport();
            service.request("ipc");
        }
    }
}
