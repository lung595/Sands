import QtQuick
import qs.Services

// Preview stand-in: no program is started (no sound on the real PipeWire, no
// real notification). A player "plays" for `playMs` then exits with 0, like
// pw-play at the end of the file; a notification stays open until it is
// stopped. Stopping a running process sends `exited`, as Quickshell does.
QtObject {
    id: process

    property var command: []
    property bool running: false
    property bool stdinEnabled: false
    function write(data) {
    }
    property var environment: ({})
    property QtObject stdout: null
    property QtObject stderr: null
    property int playMs: 1000
    signal started
    signal exited(int exitCode, int exitStatus)

    // String() is not callable on a list entry here, so concatenate
    readonly property bool _stays: command.length > 0 && ("" + command[0]).indexOf("notify") >= 0
    // A `dms` call is answered at once by the mocked Alex in PluginService
    readonly property bool _isDms: command.length > 0 && command[0] === "dms"
    property Timer _end: Timer {
        interval: process._isDms ? 1 : process.playMs
        onTriggered: {
            process.running = false;
        }
    }
    property bool _wasRunning: false

    onRunningChanged: {
        if (running) {
            _wasRunning = true;
            started();
            if (_isDms) {
                const reply = PluginService.dms(command);
                if (stdout) {
                    stdout.text = reply;
                    stdout.streamFinished();
                }
            }
            if (!_stays)
                _end.restart();
        } else if (_wasRunning) {
            _wasRunning = false;
            _end.stop();
            if (stdout && stdout.finish)
                stdout.finish();
            exited(0, 0);
        }
    }
}
