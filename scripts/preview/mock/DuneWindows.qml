import QtQuick

// Bench stand-in for components/alert/DuneWindows.qml: the real one needs a
// layer shell, which no offscreen run has. Same surface, no window. The dune
// scene is only built when a timer rings, so at rest this file is compiled
// and never created.
Item {
    id: root

    property string style: ""
    property string name: ""
    property string reason: ""
    property bool overFullscreen: false
    property int seed: 1
    property var screenNames: []

    signal finished
    signal stopRequested

    function dismiss() {
        root.finished();
    }
}
