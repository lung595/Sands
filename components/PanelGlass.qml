import QtQuick
import qs.Common

// The hourglass part of the panel: the glass, the frost around it, the
// gestures and the dots. It shows what it is given and reports what the
// user does; the panel decides (TimerPanelContent.qml).
Item {
    id: root

    required property var daemon
    // The timer shown (or null) and its state
    required property var timer
    required property string timerState
    required property real remaining
    required property color accent
    required property real frost
    required property color frostColor
    required property bool reducedMotion
    // false when the panel is closed: every animation stops
    required property bool animate
    // Space the panel leaves above this item (the mist reaches into it)
    required property real topInset
    required property var ids
    required property int index

    // The hourglass effects clock, shared with the frost and the clock text
    readonly property alias fxTime: glass.fxTime

    signal switchTimer(int step)
    signal pickTimer(int id, int dir)
    signal addMinute(int step)

    height: 236

    // Frost is built only while it is visible: it melts away on resume.
    readonly property bool frosted: frost > 0.005

    Hourglass {
        id: glass
        anchors.fill: parent
        progress: root.daemon ? root.daemon.progressOf(root.timer) : 0
        running: root.timerState === "running"
        paused: root.timerState === "paused"
        ringing: root.timerState === "ringing"
        frost: root.frost
        frostColor: root.frostColor
        animate: root.animate
        reducedMotion: root.reducedMotion
        sandColor: root.timerState === "ringing" ? Theme.error : ((root.timerState === "running" && root.remaining <= 60000) ? Theme.warning : root.accent)
        glassColor: Theme.surfaceText
        capColor: Theme.surfaceContainerHighest
        style: root.daemon ? root.daemon.hourglassStyle : "classic"

        // Restart: the hourglass turns over.
        Connections {
            target: root.daemon
            function onTimerStarted(id) {
                if (root.timer && root.timer.id === id)
                    glass.flip();
            }
        }
    }

    // Cold mist behind the hourglass
    Loader {
        z: -1
        anchors.fill: parent
        active: root.frosted
        sourceComponent: FrostMist {
            frost: root.frost
            frostColor: root.frostColor
            reducedMotion: root.reducedMotion
            fxTime: glass.fxTime
            topInset: root.topInset
        }
    }

    // Frost dust in front
    Loader {
        anchors.fill: parent
        active: root.frosted
        sourceComponent: FrostDust {
            frost: root.frost
            reducedMotion: root.reducedMotion
            fxTime: glass.fxTime
        }
    }

    GlassGestures {
        anchors.centerIn: parent
        width: 190
        height: parent.height
        active: !!root.timer
        onTapped: glass.wild()
        onSwitchTimer: step => root.switchTimer(step)
        onAddMinute: step => root.addMinute(step)
    }

    TimerDots {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4
        daemon: root.daemon
        ids: root.ids
        currentId: root.timer ? root.timer.id : -1
        currentIndex: root.index
        onPicked: (id, dir) => root.pickTimer(id, dir)
    }
}
