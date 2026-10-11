import QtQuick
import Quickshell

// One Edge halo window per screen
Variants {
    id: root

    property real level: 0
    property string legend: ""

    signal stopRequested

    model: Quickshell.screens

    HaloWindow {
        level: root.level
        legend: root.legend
        onStopRequested: root.stopRequested()
    }
}
