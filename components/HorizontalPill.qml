import QtQuick
import qs.Common
import qs.Widgets
import "../TimeParser.js" as TP
import "Motion.js" as Motion

// Horizontal bar pill: glyph, timer name, time left, « +n » badge.
// Reads the daemon's state; the host passes it in with the bar metrics.
Item {
    id: pill

    property var daemon: null
    // Locked session or screens off: nobody sees the pill, so it stops
    // moving (the alarm sound still rings).
    property bool asleep: false
    property real barThickness: 40
    property real widgetThickness: 30
    property var barConfig: null

    // Right after a start, show THIS timer (name + duration) for 2 s.
    property int flashId: -1
    readonly property var flashTimer: flashId >= 0 && daemon ? daemon.find(flashId) : null
    readonly property var t: flashTimer || daemon?.primary || null
    readonly property string st: t ? t.state : "idle"
    readonly property real rem: t && daemon ? daemon.remainingOf(t) : 0
    readonly property bool urgent: st === "running" && rem <= 60000
    readonly property bool finalCountdown: st === "running" && rem <= 10000
    // Motion only when something moves, and never with Reduce motion
    // (the ringing background still breathes: it is the alert).
    readonly property bool beating: finalCountdown && !SettingsData.reduceMotion
    readonly property bool bellShaking: st === "ringing" && (daemon?.soundActive ?? false) && !SettingsData.reduceMotion
    readonly property bool showLabel: st === "ringing" || flashTimer !== null || dwell.open

    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    readonly property real pad: (barConfig?.removeWidgetPadding ?? false) ? 0 : (barConfig?.widgetPadding ?? 12) * (widgetThickness / 30)
    readonly property string timeText: st === "ringing" ? "Done" : TP.formatClock(rem)
    readonly property int others: Math.max(0, (daemon?.count ?? 0) - 1)
    readonly property color accent: st === "ringing" ? Theme.error : (urgent ? Theme.warning : (daemon && t ? daemon.colorFor(t) : Theme.primary))

    implicitWidth: row.implicitWidth
    implicitHeight: widgetThickness - pad * 2

    // The whole bar cell around the pill (the host pads it): hover, clicks
    // and the alert background cover it.
    Item {
        id: cell
        x: -pill.pad
        y: -pill.pad
        width: pill.width + pill.pad * 2
        height: pill.height + pill.pad * 2
    }

    HoverDwell {
        id: dwell
        anchors.fill: cell
    }

    PillClock {
        id: clock
        daemon: pill.daemon
        timerState: pill.st
        fast: pill.bellShaking
        running: !pill.asleep && ((pill.st === "ringing" && !clock.settled) || pill.beating)
    }

    Connections {
        target: pill.daemon
        function onTimerStarted(id) {
            pill.flashId = id;
            flashEnd.restart();
        }
    }

    Timer {
        id: flashEnd
        interval: 2200
        onTriggered: pill.flashId = -1
    }

    // Alert background that breathes while ringing.
    Rectangle {
        anchors.fill: cell
        radius: Theme.cornerRadius
        color: Theme.error
        visible: pill.st === "ringing"
        // Breathes between 0.16 and 0.4 every 1.4 s.
        opacity: visible && !clock.settled ? Motion.wave(clock.fxMs / 1000, 1.4, 0.16, 0.4) : 0.28
    }

    PillClicks {
        anchors.fill: cell
        daemon: pill.daemon
        target: pill.t
        ringing: pill.st === "ringing"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(pill.textSize * 0.45)

        PillGlyph {
            anchors.verticalCenter: parent.verticalCenter
            daemon: pill.daemon
            target: pill.t
            timerState: pill.st
            textSize: pill.textSize
            accent: pill.accent
            fxMs: clock.fxMs
            beating: pill.beating
            bellShaking: pill.bellShaking
        }

        PillNameLabel {
            anchors.verticalCenter: parent.verticalCenter
            shown: pill.showLabel
            text: pill.daemon ? pill.daemon.displayLabel(pill.t) : ""
            textSize: pill.textSize
            ringing: pill.st === "ringing"
        }

        PillTimeLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.timeText
            timerState: pill.st
            urgent: pill.urgent
            textSize: pill.textSize
        }

        // Finished: an explicit ✕ (any click on the pill also stops it).
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.st === "ringing"
            name: "close"
            size: Math.round(pill.textSize * 1.1)
            color: Theme.error
        }

        PillBadge {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.others > 0 && pill.st !== "ringing"
            count: pill.others
            textSize: pill.textSize
        }
    }
}
