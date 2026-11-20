import QtQuick
import qs.Common
import ".."

// The panel's hourglass, small: drawn at 88×100 and scaled down, so all its
// pixel constants shrink together. No halo (clipped), no shadow, no frost.
// `animate` false freezes it: the clock stops, the sand still follows the
// level (once a second, with the daemon's clock).
Item {
    id: root

    required property var daemon
    // The timer drawn, or null: a still, full hourglass (a favourite)
    property var timer: null
    property bool animate: false
    // Height on screen; the width follows the 88:100 drawing
    property real size: 42
    property color accent: Theme.primary

    readonly property string tstate: timer ? timer.state : ""
    readonly property real remaining: (daemon && timer) ? daemon.remainingOf(timer, daemon.now) : 0
    readonly property alias glass: glass

    // Turned over once: a restart both signals and jumps the time
    property real _flippedAt: 0
    function flip() {
        if (!root.animate || Date.now() - root._flippedAt < 800)
            return;
        root._flippedAt = Date.now();
        glass.flip();
    }

    // +time (the chips, a snooze) turns it over too: the time left jumps
    // up by more than the clock can explain
    property int _seenId: -1
    property real _seen: 0
    onRemainingChanged: {
        const id = root.timer ? root.timer.id : -1;
        if (id === root._seenId && id >= 0 && root.remaining - root._seen > 30000)
            root.flip();
        root._seenId = id;
        root._seen = root.remaining;
    }

    implicitWidth: Math.round(size * 0.88)
    implicitHeight: size
    clip: true

    Hourglass {
        id: glass
        width: 88
        height: 100
        anchors.centerIn: parent
        scale: root.size / 100
        transformOrigin: Item.Center
        progress: (root.daemon && root.timer) ? root.daemon.progressOf(root.timer) : 1
        running: root.tstate === "running"
        paused: root.tstate === "paused" || root.tstate === ""
        ringing: root.tstate === "ringing"
        frost: 0
        animate: root.animate
        reducedMotion: !root.animate
        sandColor: root.tstate === "ringing" ? Theme.error : ((root.tstate === "running" && root.remaining <= 60000) ? Theme.warning : root.accent)
        glassColor: Theme.surfaceText
        capColor: Theme.surfaceContainerHighest
        bare: true
        style: root.daemon && root.daemon.hourglassStyle ? root.daemon.hourglassStyle : "classic"
    }

    // A restart turns it over (also when the time does not jump: a short one)
    Connections {
        target: root.daemon
        ignoreUnknownSignals: true
        function onTimerStarted(id) {
            if (root.timer && root.timer.id === id)
                root.flip();
        }
    }
}
