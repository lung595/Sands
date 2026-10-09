import QtQuick
import qs.Common
import qs.Widgets

// Vertical bar pill: ring + short time (« 18m », « 42s »).
Column {
    id: vpill

    property var daemon: null
    property real barThickness: 40
    property var barConfig: null

    readonly property var t: daemon?.primary ?? null
    readonly property string st: t ? t.state : "idle"
    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    readonly property real rem: t && daemon ? daemon.remainingOf(t) : 0

    spacing: 2

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(vpill.textSize * 1.3)
        height: width

        ProgressRing {
            anchors.fill: parent
            progress: vpill.daemon ? vpill.daemon.progressOf(vpill.t) : 0
            thickness: Math.max(2, Math.round(width * 0.14))
            color: vpill.st === "ringing" ? Theme.error : (vpill.st === "paused" ? Theme.withAlpha(Theme.widgetTextColor, 0.5) : (vpill.daemon && vpill.t ? vpill.daemon.colorFor(vpill.t) : Theme.primary))
            trackColor: Theme.withAlpha(Theme.widgetTextColor, 0.16)
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
            const s = Math.ceil(Math.abs(vpill.rem) / 1000);
            if (s >= 3600)
                return Math.floor(s / 3600) + "h";
            if (s >= 60)
                return Math.ceil(s / 60) + "m";
            return s + "s";
        }
        font.pixelSize: Math.round(vpill.textSize * 0.85)
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
        color: vpill.st === "ringing" ? Theme.error : Theme.widgetTextColor
    }
}
