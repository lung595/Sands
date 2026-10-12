import QtQuick

// Preview stand-in: nothing is read from the disk. A file "loads" on the next
// turn of the event loop with the made-up `content`, as the real FileView
// answers after it was asked (never inside the call that set the path).
QtObject {
    id: view

    property string path: ""
    property bool blockLoading: false
    property bool printErrors: true
    // What text() answers; never empty, so the file always counts as there
    property string content: "preview"

    signal loaded
    signal loadFailed(int error)

    function text() {
        return content;
    }
    function reload() {
        if (path !== "")
            Qt.callLater(view.loaded);
    }

    onPathChanged: reload()
}
