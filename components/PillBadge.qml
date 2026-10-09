import QtQuick
import qs.Common
import qs.Widgets

// « +2 »: other running timers.
Rectangle {
    id: badge

    property int count: 0
    property real textSize: 14

    height: Math.round(textSize * 1.15)
    width: Math.max(height, badgeText.implicitWidth + Math.round(textSize * 0.6))
    radius: height / 2
    color: Theme.withAlpha(Theme.primary, 0.18)

    StyledText {
        id: badgeText
        anchors.centerIn: parent
        text: "+" + badge.count
        font.pixelSize: Math.round(badge.textSize * 0.78)
        font.weight: Font.DemiBold
        font.features: {
            "tnum": 1
        }
        color: Theme.primary
    }
}
