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
    property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/sands"
    readonly property string path: dir + "/history.json"

    // After the last pending step of append(), erase() or removeAll() ends
    signal settled

    property var _pending: []    // finished timers waiting to be written
    property var _steps: []      // disk steps still to run: { kind, text }
    property bool _busy: false

    // Keeps a finished timer: { name, start, end } in epoch ms. Entries that
    // arrive while a write is running are folded into the next one.
    function append(entry) {
        _pending.push(entry);
        _kick();
    }

    // Deletes the history in one call; the folder stays for the next timer
    function erase() {
        _pending = [];
        _steps.push({
            kind: "erase"
        });
        _kick();
    }

    // Deletes the file and the folder (uninstall)
    function removeAll() {
        _pending = [];
        _steps.push({
            kind: "remove"
        });
        _kick();
    }

    function _kick() {
        if (_busy)
            return;
        if (_steps.length === 0 && _pending.length > 0)
            _steps.push({
                kind: "read"
            });
        if (_steps.length === 0) {
            settled();
            return;
        }
        _busy = true;
        const step = _steps.shift();
        _io.step = step;
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

    function _done() {
        _busy = false;
        _kick();
    }

    // The read step ended with `text`: fold the pending entries in, then write
    function _onRead(text) {
        const now = Date.now();
        let h = History.parse(text, now);
        for (const e of _pending)
            h = History.add(h, e.name, e.start, e.end, now);
        _pending = [];
        _steps.unshift({
            kind: "write",
            text: History.serialize(h)
        });
    }

    property Process _io: Process {
        property var step: null

        stdinEnabled: true
        stdout: StdioCollector {
            // Only the read step uses its output; the others print nothing
            onStreamFinished: {
                if (store._io.step && store._io.step.kind === "read")
                    store._onRead(text);
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
            store._done();
        }
    }
}
