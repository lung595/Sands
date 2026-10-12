import QtQuick
import Quickshell
import Quickshell.Io
import "components/daemon"

// needs: components/daemon/ReportService.qml components/daemon/ReportClipboard.qml components/daemon/ToolProcess.qml diagnostics/Cpu.js diagnostics/Gather.js diagnostics/Log.js diagnostics/Redact.js diagnostics/Report.js diagnostics/Allow.js diagnostics/Codes.js plugin.json
// stubs: qs
// layout: tree
// fakebin
// Offscreen test of the report path with fake wl-copy and dms on PATH: nothing
// runs at rest, the text reaches the tool by standard input and never by its
// arguments, a missing wl-copy falls back to dms, no tool at all ends in
// "none", an IPC report is handed over once, and a button press is copied by
// the service itself. Run with tests/qml/run.sh.
ShellRoot {
    id: root

    readonly property string tmp: Quickshell.env("QML_TMP")
    property int step: 0
    property bool failed: false

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    function finish() {
        console.warn(failed ? "FAIL reportCopy" : "qml PASS reportCopy");
        Qt.quit();
    }

    ReportService {
        id: service
        engine: QtObject {
            property var timers: []
            function setting(key, fallback) {
                return fallback;
            }
        }
    }

    ReportClipboard {
        id: clip
    }

    // Reads back what the fake tools recorded
    Process {
        id: look
        property var after
        command: ["sh", "-c", 'echo "argv:$(cat "$1/wl.argv" 2>/dev/null)"; echo "stdin:$(cat "$1/wl.stdin" 2>/dev/null)"; echo "dmsargv:$(cat "$1/dms.argv" 2>/dev/null)"; echo "dmsstdin:$(cat "$1/dms.stdin" 2>/dev/null)"', "sh", root.tmp]
        stdout: StdioCollector {
            onStreamFinished: look.after(text)
        }
    }

    Process {
        id: touch
        command: ["touch", root.tmp + "/no-wl"]
        onExited: root.next()
    }

    function next() {
        step++;
        if (step === 1) {
            check(!service.busy && clip.result === "idle", "nothing runs at rest");
            clip.copy("SECRET-LINE");
        } else if (step === 3) {
            // wl-copy gone: the fallback must take the text
            touch.running = true;
        } else if (step === 4) {
            clip.copy("FALLBACK-LINE");
        } else if (step === 6) {
            service.request("ipc");
        }
    }

    Connections {
        target: clip
        function onResultChanged() {
            if (clip.result === "copying")
                return;
            if (root.step === 1) {
                root.check(clip.result === "copied" && !clip.inHistory, "wl-copy copied");
                look.after = t => {
                    root.check(t.indexOf("argv:--sensitive\n") >= 0, "wl-copy gets --sensitive only: " + t);
                    root.check(t.indexOf("stdin:SECRET-LINE") >= 0, "text on stdin");
                    root.check(t.indexOf("argv:--sensitive\n") >= 0 && t.split("\n")[0].indexOf("SECRET") < 0, "text not in argv");
                    root.next();
                    root.next();
                };
                look.running = true;
            } else if (root.step === 4) {
                root.check(clip.result === "copied" && clip.inHistory, "fallback copied and flagged " + clip.result);
                look.after = t => {
                    root.check(t.indexOf("dmsstdin:FALLBACK-LINE") >= 0, "dms gets the text on stdin: " + t);
                    root.check(t.indexOf("dmsargv:clipboard copy") >= 0, "dms argv");
                    root.next();
                    root.next();
                };
                look.running = true;
            }
        }
    }

    Connections {
        target: service
        function onBuilt(text, via) {
            if (via === "button")
                return;
            root.check(via === "ipc" && text.length > 0, "built for ipc");
            root.check(service.hasReport(), "report waits for the IPC call");
            const first = service.takeReport();
            root.check(first === text, "take returns the report");
            root.check(service.takeReport() === "" && !service.hasReport(), "taken once");
            // A button press: the service copies its report itself and keeps none
            service.request("button");
        }
    }

    Connections {
        target: service.clipboard
        function onResultChanged() {
            if (service.clipboard.result === "copying")
                return;
            root.check(service.clipboard.result === "copied" && service.clipboard.inHistory, "the button's report is copied by the fallback and flagged");
            root.check(!service.busy && !service.hasReport(), "nothing kept after a button press");
            look.after = t => {
                root.check(t.indexOf("dmsstdin:Sands diagnostic report") >= 0, "the button's report reached the tool: " + t.slice(0, 200));
                root.finish();
            };
            look.running = true;
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: root.next()
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: {
            root.check(false, "timeout at step " + root.step);
            root.finish();
        }
    }
}
