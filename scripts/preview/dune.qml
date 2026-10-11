import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/alert"

// Offscreen render of the Rising dune band from a made-up timer name.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports dune.qml -- [light] [reduce] <width> <name> <out.png> [mid]
// A "style=wind" or "style=wave" argument anywhere picks the sand style.
// "mid" takes the picture at 1.2 s instead of at the end ("early": 0.5 s); "light" and
// "reduce" are read by the Theme and SettingsData stand-ins.
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property bool early: args[args.length - 1] === "early"
    readonly property bool mid: early || args[args.length - 1] === "mid"
    readonly property int tail: mid ? 1 : 0
    readonly property string out: args[args.length - 1 - tail]
    readonly property string label: args[args.length - 2 - tail]
    readonly property string sand: (args.find(a => a.indexOf("style=") === 0) || "style=grains").slice(6)
    readonly property int bandWidth: parseInt(args[args.length - 3 - tail])

    width: bandWidth
    height: 200
    visible: true
    color: Theme.surface

    DuneBand {
        id: band
        anchors.fill: parent
        name: win.label
        style: win.sand
        reduceMotion: SettingsData.reduceMotion
        seed: 7
    }

    Timer {
        interval: 50
        running: true
        onTriggered: band.shown = true
    }

    // Done when the motion model says so (or at 1.2 s for the mid picture)
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (band.shown && (win.mid ? band.duneState.step >= (win.early ? 15 : 36) : band.duneState.done)) {
                stop();
                win.contentItem.grabToImage(r => {
                    r.saveToFile(win.out);
                    Qt.quit();
                });
            }
        }
    }
}
