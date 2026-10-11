import QtQuick

// Preview stand-in: collects nothing. The scan never runs here; the mock
// Process calls `finish` on exit so readers waiting on the stream complete.
QtObject {
    property string text: ""
    signal streamFinished
    function finish() {
        streamFinished();
    }
}
