pragma ComponentBehavior: Bound
import QtQuick
import "AlertPolicy.js" as AlertPolicy
import "../daemon/PlainText.js" as PlainText

// Host of the visual alert of a finished timer. Reads the kind and the moment
// through AlertPolicy and holds at most one scene in a Loader that exists only
// from the ring point to the dismissal: nothing exists at rest.
Item {
    id: root

    // Saved choices; unknown values fall back to the defaults in AlertPolicy
    property string kind: "dune"
    property string when: "always"
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
    // Untyped on purpose: the scene is a dune or a halo, both honour
    // dismiss() and finished
    readonly property var scene: loader.item

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
        // The name comes from the user or a launcher: no em dash on screen
        return PlainText.plain(name) + " is done" + (reason ? " · " + reason : "");
    }

    // Destroys the scene and clears the test flag. Internal: every exit path
    // (finished signal, scene without dismiss(), a real alert ringing) ends here
    // so that a test never leaves its state behind.
    function _loaderOff() {
        testEnd.stop();
        loader.active = false;
        _testing = false;
    }

    // Called at the ring point
    function ring() {
        // A real alert replaces a test that is still playing
        if (_testing)
            _loaderOff();
        if (loader.active)
            return;
        if (_scene && AlertPolicy.shouldShow(kind, when, soundState, fullscreen, showOverFullscreen))
            loader.active = true;
    }

    // Called when the alert is dismissed (stop, snooze, delete)
    function dismiss() {
        // The stale test end must not dismiss a later alert
        testEnd.stop();
        if (scene && typeof scene.dismiss === "function")
            scene.dismiss();
        else
            _loaderOff();
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
            legend: root._legend(root._testing ? "Pasta" : root.timerName)
            windowed: root.windowed
            onStopRequested: root.dismiss()
        }
    }

    Loader {
        id: loader
        active: false
        sourceComponent: root._scene
    }

    // The scene says when its exit is over; a scene without the signal is ignored
    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onFinished() {
            root._loaderOff();
        }
    }
}
