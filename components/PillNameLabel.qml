import QtQuick
import qs.Common
import qs.Widgets

// Timer name: unfolds on start, on hover and at the end.
Item {
    id: clip

    property bool shown: false
    property string text: ""
    property real textSize: 14
    property bool ringing: false

    readonly property real fullWidth: Math.min(labelRow.implicitWidth, textSize * 11)
    width: shown ? fullWidth : 0
    height: labelRow.implicitHeight
    clip: true
    opacity: shown ? 1 : 0
    visible: width > 0.5

    Behavior on width {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 220
        }
    }

    Row {
        id: labelRow
        spacing: Math.round(clip.textSize * 0.35)

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: clip.text
            width: Math.min(implicitWidth, clip.textSize * 11 - dot.implicitWidth - parent.spacing)
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: clip.textSize
            font.weight: Font.DemiBold
            color: clip.ringing ? Theme.error : Theme.widgetTextColor
        }

        StyledText {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            text: "·"
            font.pixelSize: clip.textSize
            color: Theme.withAlpha(Theme.widgetTextColor, 0.45)
        }
    }
}
