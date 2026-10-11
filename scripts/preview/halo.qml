import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/alert"

// Offscreen render of the Edge halo rim and legend from a made-up name.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports halo.qml -- [light] <mode> <out.png>
// Modes: wide, narrow (360 px), long (very long name), longnarrow, reduce (Reduce motion).
// The window backend is off (windowed: false); HaloRim is what the overlay draws.
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]
    readonly property string out: args[args.length - 1]

    width: (mode === "narrow" || mode === "longnarrow") ? 360 : 960
    height: (mode === "narrow" || mode === "longnarrow") ? 240 : 540
    visible: true

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    HaloScene {
        id: scene
        windowed: false
        reduceMotion: win.mode === "reduce"
        legend: (win.mode.indexOf("long") === 0 ? "Slow roasted lamb shoulder with rosemary and garlic" : "Pasta") + " is done · Sound is muted"
    }

    HaloRim {
        anchors.fill: parent
        level: scene.level
        legend: scene.legend
    }

    // Long enough for the rise and the 3 beats to be over
    Timer {
        interval: 2300
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
