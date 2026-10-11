import QtQuick
import qs.Common
import "HaloMotion.js" as HaloMotion

// Edge halo: a 4 px rim in the primary colour around each screen, plus the
// legend of the alert. One finite list of steps walked by a Timer at 30 Hz,
// which stops by itself on the last one: afterwards nothing repaints until
// dismiss() fades the rim out. No QML animation, so the rest of the shell is
// never redrawn by it.
Item {
    id: root

    // "Pasta is done · Sound is muted", built by the host
    required property string legend
    property bool reduceMotion: SettingsData.reduceMotion
    // Names of the screens that get a rim, handed to the windows
    property var screenNames: []

    // Emitted once the exit has finished (or at once with Reduce motion)
    signal finished
    // The user clicked the legend
    signal stopRequested

    // Current opacity of the rim, 0..1. Reduce motion shows the posed rim at once.
    property real level: reduceMotion ? HaloMotion.posed() : 0
    readonly property bool running: clock.running

    property var _steps: reduceMotion ? [] : HaloMotion.steps(false)
    property int _index: 0
    property bool _leaving: false

    function dismiss() {
        if (_leaving)
            return;
        _leaving = true;
        _steps = reduceMotion ? [] : HaloMotion.exitSteps(level);
        _index = 0;
        if (_steps.length === 0) {
            level = 0;
            finished();
        } else {
            clock.restart();
        }
    }

    Component.onCompleted: if (_steps.length > 0)
        clock.start()

    // Only alive while steps remain; stops itself on the last one.
    Timer {
        id: clock
        interval: 1000 / 30
        repeat: true
        onTriggered: {
            const s = root._steps[root._index++];
            root.level = s.opacity;
            if (root._index >= root._steps.length) {
                stop();
                if (root._leaving)
                    root.finished();
            }
        }
    }

    // Off in tests: the offscreen platform has no layer shell backend, so the
    // window file is not even parsed there (the source is a path, resolved on use).
    property bool windowed: true

    Loader {
        id: windows
        active: root.windowed
        source: "HaloWindows.qml"
    }

    Binding {
        target: windows.item
        property: "level"
        value: root.level
        when: windows.item !== null
    }

    Binding {
        target: windows.item
        property: "legend"
        value: root.legend
        when: windows.item !== null
    }

    Binding {
        target: windows.item
        property: "screenNames"
        value: root.screenNames
        when: windows.item !== null
    }

    Connections {
        target: windows.item
        ignoreUnknownSignals: true
        function onStopRequested() {
            root.stopRequested();
        }
    }
}
