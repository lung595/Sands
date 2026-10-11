import QtQuick
import "AlertPolicy.js" as AlertPolicy

// Host of the visual alert of a finished timer. Reads the kind and the moment
// through AlertPolicy and holds at most one scene in a Loader that exists only
// from the ring point to the dismissal: nothing exists at rest.
Item {
    id: root

    // Saved choices; unknown values fall back to the defaults in AlertPolicy
    property string kind: "dune"
    property string when: "muted"
    // { choice, volume, outputMuted, hasOutput }
    property var soundState: ({})
    property bool fullscreen: false
    property bool showOverFullscreen: false
    // Name of the finished timer, shown in the legend
    property string timerName: ""
    // The dune scene, supplied by the wiring (null until it is wired): the host
    // draws nothing rather than failing when it is missing.
    property Component duneScene: null
    // False on a session without layer shell (X11): the halo cannot be drawn
    property bool layerShell: Qt.platform.pluginName === "wayland"
    // False only in offscreen tests, which have no window backend
    property bool windowed: true

    // Read by the settings page to grey the halo card
    readonly property bool haloAvailable: layerShell
    readonly property bool showing: loader.active
    readonly property alias scene: loader.item

    // True while test() plays
    property bool _testing: false

    readonly property string _kind: AlertPolicy.kindOf(kind)

    readonly property Component _scene: {
        if (_kind === "halo")
            return haloAvailable ? haloComponent : null;
        return _kind === "dune" ? duneScene : null;
    }

    function _legend(name) {
        const reason = AlertPolicy.legendReason(kind, _testing ? "muted" : when, _testing ? {
            hasOutput: false
        } : soundState);
        return name + " is done" + (reason ? " · " + reason : "");
    }

    // Called at the ring point
    function ring() {
        if (loader.active)
            return;
        if (_scene && AlertPolicy.shouldShow(kind, when, soundState, fullscreen, showOverFullscreen))
            loader.active = true;
    }

    // Called when the alert is dismissed (stop, snooze, delete)
    function dismiss() {
        if (loader.item && typeof loader.item.dismiss === "function")
            loader.item.dismiss();
        else
            loader.active = false;
    }

    // Plays the current choice once with the fake name "Pasta", then dismisses
    // itself. The moment is ignored (the user asked to see it) but full screen
    // is still respected.
    function test() {
        if (loader.active || !_scene)
            return;
        if (!AlertPolicy.shouldShow(kind, "always", {}, fullscreen, showOverFullscreen))
            return;
        _testing = true;
        timerName = "Pasta";
        loader.active = true;
        testEnd.restart();
    }

    // One-shot, started only by test(): lets the scene play its beats
    Timer {
        id: testEnd
        interval: 2500
        onTriggered: root.dismiss()
    }

    Component {
        id: haloComponent
        HaloScene {
            legend: root._legend(root.timerName)
            windowed: root.windowed
            onStopRequested: root.dismiss()
        }
    }

    function loaderOff() {
        loader.active = false;
        _testing = false;
    }

    Loader {
        id: loader
        active: false
        sourceComponent: root._scene
        onLoaded: if (item && item.finished)
            item.finished.connect(root.loaderOff)
    }
}
