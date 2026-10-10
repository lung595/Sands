import QtQuick
import Quickshell
import Quickshell.Io

// needs: components/daemon/HistoryStore.qml components/daemon/History.js
// Offscreen test of HistoryStore against a real temporary folder.
// Run with tests/qml/run.sh; any failure prints FAIL and exits 1.
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

    HistoryStore {
        id: store
        dir: root.tmp + "/sands"
    }

    // Reads the file's mode, the folder's mode and the file's content
    Process {
        id: probe
        property var after
        // Prints "-" for a missing path so no locale-dependent message is parsed
        command: ["sh", "-c", 'stat -c %a -- "$1" 2>/dev/null || echo -; stat -c %a -- "$2" 2>/dev/null || echo -; cat -- "$2" 2>/dev/null; true', "sh", store.dir, store.path]
        stdout: StdioCollector {
            onStreamFinished: probe.after(text.split("\n"))
        }
    }

    function look(cb) {
        probe.after = cb;
        probe.running = true;
    }

    Connections {
        target: store
        function onSettled() {
            root.next();
        }
    }

    function next() {
        step++;
        const now = Date.now();
        if (step === 1) {
            store.append({
                name: "Tea",
                start: now - 600000,
                end: now - 300000
            });
        } else if (step === 2) {
            look(l => {
                check(l[0] === "700" && l[1] === "600", "modes " + l[0] + " " + l[1]);
                check(l[2].indexOf('"Tea"') > 0, "content has Tea");
                // Two quick appends fold into one write, none lost
                store.append({
                    name: "A",
                    start: now - 200000,
                    end: now - 100000
                });
                store.append({
                    name: "B",
                    start: now - 90000,
                    end: now - 10000
                });
            });
        } else if (step === 3) {
            look(l => {
                check(l[2].indexOf('"A"') > 0 && l[2].indexOf('"B"') > 0 && l[2].indexOf('"Tea"') > 0, "three records");
                // An append queued right after an erase must survive it
                store.append({
                    name: "Old",
                    start: now - 80000,
                    end: now - 70000
                });
                store.erase();
                store.append({
                    name: "New",
                    start: now - 60000,
                    end: now - 50000
                });
            });
        } else if (step === 4) {
            look(l => {
                check(l[2].indexOf('"New"') > 0 && l[2].indexOf('"Old"') < 0 && l[2].indexOf('"Tea"') < 0, "append after erase kept");
                store.erase();
            });
        } else if (step === 5) {
            look(l => {
                check(l[1] === "-", "file erased: " + l[1]);
                check(l[2] === undefined || l[2] === "", "no content after erase");
                // A corrupted file reads as empty and is replaced by a good one
                writer.running = true;
            });
        } else if (step === 6) {
            look(l => {
                check(l[1] === "600" && l[2].indexOf('"Z"') > 0 && l[2].indexOf("garbage") < 0, "corrupt file recovered");
                // An unreadable file reads as empty and is replaced as well
                locker.running = true;
            });
        } else if (step === 7) {
            look(l => {
                check(l[1] === "600" && l[2].indexOf('"Y"') > 0 && l[2].indexOf('"Z"') < 0, "unreadable file recovered");
                store.removeAll();
            });
        } else if (step === 8) {
            look(l => {
                check(l[0] === "-" && l[1] === "-", "folder and file removed");
                console.warn(failed ? "FAIL" : "PASS");
                Qt.exit(failed ? 1 : 0);
            });
        }
    }

    // Plants garbage in the history file, then appends over it
    Process {
        id: writer
        command: ["sh", "-c", 'umask 077; mkdir -p -- "$1" && printf "garbage{" > "$2"', "sh", store.dir, store.path]
        onExited: store.append({
            name: "Z",
            start: Date.now() - 50000,
            end: Date.now() - 1000
        })
    }

    // Makes the history file unreadable, then appends over it
    Process {
        id: locker
        command: ["chmod", "000", "--", store.path]
        onExited: store.append({
            name: "Y",
            start: Date.now() - 40000,
            end: Date.now() - 1000
        })
    }

    Component.onCompleted: next()
}
