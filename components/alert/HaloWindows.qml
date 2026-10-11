pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "AlertPolicy.js" as Policy

// One Edge halo window per chosen screen
Variants {
    id: root

    property real level: 0
    property string legend: ""
    // Names of the screens to draw on; a list that matches no screen draws on all
    property var screenNames: []

    signal stopRequested

    model: Policy.pickScreens(Quickshell.screens, root.screenNames)

    HaloWindow {
        level: root.level
        legend: root.legend
        onStopRequested: root.stopRequested()
    }
}
