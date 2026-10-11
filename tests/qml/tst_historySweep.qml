import QtQuick
import Quickshell
import Quickshell.Io

// needs: components/daemon/HistorySweep.qml
// Offscreen test of the uninstall sweep with the real Quickshell: unloading the
// component removes the history and its folder only when the manifest is gone.
// Run with tests/qml/run.sh; any failure prints FAIL and exits 1.
ShellRoot {
    id: root

    readonly property string tmp: Quickshell.env("QML_TMP")
    readonly property string dir: tmp + "/state/sands"
    readonly property string manifest: tmp + "/plugin.json"
    property int step: 0
    property bool failed: false

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    // Plants the manifest (`$3` = "keep") or not, and a history file
    Process {
        id: setup
        property bool withManifest: true
        command: ["sh", "-c", 'rm -f -- "$2"; [ "$3" = keep ] && echo "{}" > "$2"; mkdir -p -- "$1" && echo "{}" > "$1/history.json"', "sh", root.dir, root.manifest, withManifest ? "keep" : "drop"]
        onExited: {
            loader.active = true;
            unloadTimer.start();
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", '[ -e "$1/history.json" ] && echo file || echo nofile; [ -d "$1" ] && echo dir || echo nodir', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.judge(text.trim().split("\n"))
        }
    }

    Loader {
        id: loader
        active: false
        sourceComponent: HistorySweep {
            manifest: "file://" + root.manifest
            dir: root.dir
            path: root.dir + "/history.json"
        }
    }

    Timer {
        id: unloadTimer
        interval: 200
        onTriggered: {
            loader.active = false;
            settle.start();
        }
    }

    // The sweep is detached: give it a moment before looking
    Timer {
        id: settle
        interval: 600
        onTriggered: probe.running = true
    }

    function judge(l) {
        if (step === 0)
            check(l[0] === "file" && l[1] === "dir", "manifest present: history kept (" + l.join(",") + ")");
        else
            check(l[0] === "nofile" && l[1] === "nodir", "manifest gone: file and folder removed (" + l.join(",") + ")");
        step++;
        if (step === 1) {
            setup.withManifest = false;
            setup.running = true;
        } else {
            console.warn(failed ? "FAIL" : "PASS");
            Qt.exit(failed ? 1 : 0);
        }
    }

    Component.onCompleted: setup.running = true
}
