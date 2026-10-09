import QtQuick
import qs.Common
import qs.Widgets
import "Motion.js" as Motion

// Leading glyph of the pill: progress ring while running, pause icon, shaking bell.
Item {
    id: glyph

    property var daemon: null
    property var target: null
    property string timerState: "idle"
    property real textSize: 14
    property color accent: Theme.primary
    property real fxMs: 0
    property bool beating: false
    property bool bellShaking: false

    width: Math.round(textSize * 1.2)
    height: width

    // Last ten seconds: one beat per second (skipped with Reduce motion).
    scale: beating ? Motion.beatScale(fxMs) : 1

    ProgressRing {
        anchors.fill: parent
        visible: glyph.timerState === "running"
        progress: glyph.daemon ? glyph.daemon.progressOf(glyph.target) : 0
        thickness: Math.max(2.5, Math.round(width * 0.2))
        color: glyph.accent
        trackColor: Theme.withAlpha(Theme.widgetTextColor, 0.2)

        Behavior on color {
            ColorAnimation {
                duration: 400
            }
        }
    }

    DankIcon {
        anchors.centerIn: parent
        visible: glyph.timerState === "paused"
        name: "pause_circle"
        filled: true
        size: parent.width
        color: Theme.withAlpha(Theme.widgetTextColor, 0.6)
    }

    DankIcon {
        anchors.centerIn: parent
        visible: glyph.timerState === "ringing"
        name: "alarm"
        filled: true
        size: parent.width
        color: Theme.error
        // Shakes while the sound plays.
        rotation: glyph.bellShaking ? Motion.bellAngle(glyph.fxMs) : 0
    }
}
