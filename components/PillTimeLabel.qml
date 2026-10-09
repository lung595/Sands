import QtQuick
import qs.Common
import qs.Widgets
import "../TimeParser.js" as TP

// Time left (or "Done") in the pill.
StyledText {
    id: label

    property string timerState: "idle"
    property bool urgent: false
    property real textSize: 14

    // Width locked to « 00:00 »: the pill does not jitter every second.
    width: timerState === "ringing" ? implicitWidth : Math.ceil(metrics.advanceWidth)
    horizontalAlignment: Text.AlignRight
    wrapMode: Text.NoWrap
    font.pixelSize: textSize
    font.weight: urgent || timerState === "ringing" ? Font.DemiBold : Font.Medium
    font.features: {
        "tnum": 1
    }
    color: {
        if (timerState === "ringing")
            return Theme.error;
        if (timerState === "paused")
            return Theme.withAlpha(Theme.widgetTextColor, 0.55);
        return urgent ? Theme.warning : Theme.widgetTextColor;
    }

    Behavior on color {
        ColorAnimation {
            duration: 400
        }
    }

    TextMetrics {
        id: metrics
        font: label.font
        text: TP.widthTemplate(label.text)
    }
}
