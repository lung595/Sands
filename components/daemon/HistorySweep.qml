import QtQuick
import Quickshell
import Quickshell.Io

// Uninstall sweep (value 12). DMS deletes nothing when a plugin is removed, so
// when the daemon unloads and our manifest is gone, the history file and its
// folder are removed here. At unload the shell may be closing, so the removal
// is a detached process (an async queue would die with its owner).
QtObject {
    id: sweep

    required property url manifest
    // The history folder and file; only ever passed as arguments, never in a shell string
    required property string dir
    required property string path

    // A fresh view per check: the daemon's own read of plugin.json stays cached
    // after the file is deleted, so the manifest is re-read here at unload only.
    property FileView _probe: FileView {
        blockLoading: true
    }

    Component.onDestruction: {
        if (dir.charAt(0) !== "/")
            return;
        _probe.path = manifest;
        _probe.reload();
        if (_probe.text() !== "")
            return;
        // Argument list with positional parameters; `--` before the data
        Quickshell.execDetached(["sh", "-c", 'rm -f -- "$2" "$2.tmp"; rmdir -- "$1" 2>/dev/null; exit 0', "sh", dir, path]);
    }
}
