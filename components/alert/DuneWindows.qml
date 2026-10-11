pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import "AlertPolicy.js" as Policy

// Scene of the dune kind: one bottom-edge layer window per screen holding a
// DuneBand. It lives only inside the DuneAlert Loader, so nothing exists at
// rest. Like every scene it honours dismiss() and emits finished.
Item {
    id: root

    property string style: ""
    property string name: ""
    property string reason: ""
    property bool overFullscreen: false
    property int seed: 1
    // Names of the screens to draw on, taken at the ring point; a list that
    // matches no screen draws on all of them
    property var screenNames: []

    readonly property int bandHeight: 200

    signal finished
    signal stopRequested

    // Starts the 150 ms fade out; the windows go once it has ended
    function dismiss() {
        _shown = false;
        linger.restart();
    }

    property bool _shown: true

    // Keeps the windows just long enough for the fade out; one-shot
    Timer {
        id: linger
        interval: 200
        onTriggered: root.finished()
    }

    Variants {
        model: Policy.pickScreens(Quickshell.screens, root.screenNames)

        PanelWindow {
            id: win

            required property var modelData
            // Snapshot when the window is created (D482): a window entering or
            // leaving full screen during the ring does not replay the rise
            property bool covered: false
            Component.onCompleted: covered = CompositorService.fullscreenToplevelOnScreen(modelData)

            screen: modelData
            visible: Policy.shouldShow(Policy.DEFAULT_KIND, "always", {}, covered, root.overFullscreen)
            color: "transparent"
            anchors {
                left: true
                right: true
                bottom: true
            }
            implicitHeight: root.bandHeight
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "dms:sands-dune"
            WlrLayershell.layer: root.overFullscreen ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Only the legend takes clicks; the dune lets everything through
            mask: Region {
                item: band.legendVisible ? band.legend : null
            }

            DuneBand {
                id: band
                anchors.fill: parent
                shown: win.visible && root._shown
                style: root.style
                name: root.name
                reason: root.reason
                reduceMotion: SettingsData.reduceMotion
                seed: root.seed
                onStopRequested: root.stopRequested()
            }
        }
    }
}
