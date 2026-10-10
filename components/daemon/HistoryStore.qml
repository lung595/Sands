import QtQuick
import Quickshell
import Quickshell.Io
import "History.js" as History

// The time journal on disk: one small file of Sands' own (mode 0600 in a 0700
// folder), read and written only when asked, so nothing runs or stays in memory
// while idle. Every disk step is one short `Process` with a command array and
// positional parameters; the data goes through stdin, never through a command
// line. A missing, unreadable or corrupted file reads as an empty history.
QtObject {
    id: store

    // Overridable so the tests never touch a real folder
    property string dir: {
        const state = Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") ? Quickshell.env("HOME") + "/.local/state" : "");
        return state ? state + "/sands" : "";
    }
    readonly property string path: dir + "/history.json"

    // After the last queued step of append(), erase() or removeAll() ends
    signal settled

    // One ordered queue, so an append made after an erase is written after it
    property var _steps: []      // { kind: "append"|"erase"|"remove", entry }
    property bool _busy: false

    // Keeps a finished timer: { name, start, end } in epoch ms. Appends that
    // queue up back to back are folded into one read and one write.
    function append(entry) {
        _enqueue({
            kind: "append",
            entry: entry
        });
    }

    // Deletes the history in one call; the folder stays for the next timer
    function erase() {
        _enqueue({
            kind: "erase"
        });
    }

    // Deletes the file and the folder (uninstall)
    function removeAll() {
        _enqueue({
            kind: "remove"
        });
    }

    function _enqueue(step) {
        // Without an absolute folder nothing may be written or removed
        if (dir.charAt(0) !== "/")
            return;
        _steps.push(step);
        _kick();
    }

    function _kick() {
        if (_busy)
            return;
        if (_steps.length === 0) {
            settled();
            return;
        }
        let step = _steps.shift();
        if (step.kind === "append") {
            const batch = [step.entry];
            while (_steps.length > 0 && _steps[0].kind === "append")
                batch.push(_steps.shift().entry);
            step = {
                kind: "read",
                batch: batch
            };
        }
        _busy = true;
        _io.step = step;
        _io.text = "";
        _io.gotText = false;
        _io.gotExit = false;
        _io.command = ["sh", "-c", _scripts[step.kind], "sh", dir, path];
        _io.running = true;
    }

    // Each script gets the folder as $1 and the file as $2
    readonly property var _scripts: ({
            // A missing file is not an error: it prints nothing
            read: 'cat -- "$2" 2>/dev/null; exit 0',
            // umask first, so the folder is born 0700 and the file 0600; the rename
            // keeps the old file whole if the write is cut
            write: 'umask 077 && mkdir -p -- "$1" && chmod 700 -- "$1" && cat > "$2.tmp" && mv -f -- "$2.tmp" "$2"',
            erase: 'rm -f -- "$2" "$2.tmp"',
            remove: 'rm -f -- "$2" "$2.tmp"; rmdir -- "$1" 2>/dev/null; exit 0'
        })

    // The step ended; a read step has `text`: fold its batch in, then write
    function _finish(step, text) {
        if (step.kind === "read") {
            const now = Date.now();
            let h = History.parse(text, now);
            for (const e of step.batch)
                h = History.add(h, e.name, e.start, e.end, now);
            _steps.unshift({
                kind: "write",
                text: History.serialize(h)
            });
        }
        _busy = false;
        _kick();
    }

    property Process _io: Process {
        property var step: null
        property string text: ""
        property bool gotText: false
        property bool gotExit: false

        // The output and the exit may arrive in either order: act on the later
        function _maybeFinish() {
            if (gotText && gotExit)
                store._finish(step, text);
        }

        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                store._io.text = text;
                store._io.gotText = true;
                store._io._maybeFinish();
            }
        }
        onStarted: {
            if (step.kind === "write")
                write(step.text);
            // Closing stdin is what lets `cat` end
            stdinEnabled = false;
        }
        onExited: {
            stdinEnabled = true;
            gotExit = true;
            _maybeFinish();
        }
    }
}
