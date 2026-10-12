import QtQuick
import Quickshell.Io

// A Process that always ends with one `finished` signal. Quickshell emits
// neither `started` nor `exited` when the program is not installed: it only
// warns and sets `running` back to false. Without this, a missing tool would
// leave its caller waiting for good. A tool that hangs is stopped after
// `limitMs` for the same reason.
Process {
    id: root

    // The exit status, -1 when the program could not be started, -2 when it
    // was stopped because it took longer than `limitMs`
    signal finished(int code)
    // The program is running: for callers that must talk to it at once
    signal launched

    // The longest a run may last; 0 means no limit
    property int limitMs: 0

    // "idle", "launching" (asked, not started yet), "running" or "ended"
    property string _phase: "idle"
    property bool _timedOut: false
    // Only runs while the program does
    property Timer _limit: Timer {
        interval: root.limitMs
        onTriggered: {
            root._timedOut = true;
            root.running = false;
        }
    }

    function launch(argv) {
        command = argv;
        _timedOut = false;
        _phase = "launching";
        running = true;
        if (limitMs > 0 && _phase !== "ended")
            _limit.restart();
    }

    function _end(code) {
        _limit.stop();
        _phase = "ended";
        finished(code);
    }

    onStarted: {
        _phase = "running";
        launched();
    }
    onRunningChanged: {
        if (!running && _phase === "launching")
            _end(-1);
    }

    // A function of Connections, not `onExited`: qmllint cannot name the type
    // of that signal's second parameter
    property Connections _ends: Connections {
        target: root
        function onExited(exitCode, exitStatus) {
            root._end(root._timedOut ? -2 : exitCode);
        }
    }
}
