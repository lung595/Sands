import QtQuick

// Preview stand-in: no program is started (no sound on the real PipeWire, no
// real notification). A player "plays" for `playMs` then exits with 0, like
// pw-play at the end of the file; a notification stays open until it is
// stopped. Stopping a running process sends `exited`, as Quickshell does.
QtObject {
    id: process

    property var command: []
    property bool running: false
    property var environment: ({})
    property QtObject stdout: null
    property QtObject stderr: null
    property int playMs: 1000
    signal started
    signal exited(int exitCode, int exitStatus)

    readonly property bool _stays: command.length > 0 && String(command[0]).indexOf("notify") >= 0
    property Timer _end: Timer {
        interval: process.playMs
        onTriggered: {
            process.running = false;
        }
    }
    property bool _wasRunning: false

    onRunningChanged: {
        if (running) {
            _wasRunning = true;
            started();
            if (!_stays)
                _end.restart();
        } else if (_wasRunning) {
            _wasRunning = false;
            _end.stop();
            exited(0, 0);
        }
    }
}
