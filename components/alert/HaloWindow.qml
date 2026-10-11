import QtQuick
import Quickshell
import Quickshell.Wayland

// One full-screen overlay window of the Edge halo. Only the legend takes
// clicks: the rest of the screen stays usable.
PanelWindow {
    id: win

    required property var modelData
    required property real level
    required property string legend

    signal stopRequested

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sands:halo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        item: rim.pill
    }

    HaloRim {
        id: rim
        anchors.fill: parent
        level: win.level
        legend: win.legend
        onStopRequested: win.stopRequested()
    }
}
