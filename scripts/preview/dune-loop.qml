import QtQuick
import QtQuick.Window
import qs.Common

// Bench scene: replays the Rising dune alert in a loop, or sits at rest after one alert.
// Usage: qml-qt6 -I imports dune-loop.qml -- <loop|rest>
// The band is loaded by path so a revision without it (the A/B base) just
// shows an empty window: the bench then reads the cost of the band alone.
Window {
    id: win

    readonly property bool loop: Qt.application.arguments[Qt.application.arguments.length - 1] === "loop"
    property int seedCounter: 1

    width: 2560
    height: 200
    visible: true
    color: Theme.surface

    Loader {
        id: host
        anchors.fill: parent
        source: Qt.resolvedUrl("../../components/alert/DuneBand.qml")
        onLoaded: {
            item.name = "Pasta";
            item.reduceMotion = false;
            item.seed = 7;
            cycle.start();
        }
    }

    // 4 s cycle: the band runs about 2.9 s then rests; "rest" mode stops after one alert
    Timer {
        id: cycle
        interval: 100
        repeat: true
        property int t: 0
        onTriggered: {
            t++;
            if (t === 1)
                host.item.shown = true;
            else if (t === 36)
                host.item.shown = false;
            else if (t === 40) {
                if (win.loop) {
                    t = 0;
                    host.item.seed = ++win.seedCounter;
                } else
                    stop();
            }
        }
    }
}
