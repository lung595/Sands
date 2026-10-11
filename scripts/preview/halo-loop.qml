import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/alert"

// Bench scene: a halo alert rings, is dismissed and destroyed, over and over,
// the way the alert host creates and drops it (one Loader).
// Usage: qml-qt6 -I imports halo-loop.qml -- <mode> /dev/null
// Modes: idle (nothing ever rings), loop (ring at 0 s, dismiss at 3 s, rest to 8 s).
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]

    width: 960
    height: 540
    visible: true

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Loader {
        id: host
        anchors.fill: parent
        active: false
        sourceComponent: Item {
            property alias scene: scene
            HaloScene {
                id: scene
                windowed: false
                legend: "Pasta is done · Sound is muted"
                onFinished: host.active = false
            }
            HaloRim {
                anchors.fill: parent
                level: scene.level
                legend: scene.legend
            }
        }
    }

    Timer {
        interval: 8000
        repeat: true
        running: win.mode === "loop"
        triggeredOnStart: true
        onTriggered: {
            host.active = true;
            dismiss.restart();
        }
    }

    Timer {
        id: dismiss
        interval: 3000
        onTriggered: if (host.item)
            host.item.scene.dismiss()
    }
}
