import QtQuick
import qs.Common
import qs.Widgets
import "../TimeParser.js" as TP
import "Motion.js" as Motion

// The clock part of the panel: name, big time, and when it ends.
Item {
    id: root

    required property var daemon
    required property var timer
    required property string timerState
    required property real remaining
    required property real frost
    required property color frostColor
    // The hourglass effects clock, for the blink while ringing
    required property real fxTime
    required property bool use24h

    height: timeCol.implicitHeight

    // Cold halo behind the clock; built only while frozen
    Loader {
        anchors.centerIn: parent
        active: root.frost > 0.005
        sourceComponent: FrostHalo {
            frost: root.frost
            frostColor: root.frostColor
        }
    }

    Column {
        id: timeCol
        width: parent.width
        spacing: 0

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.daemon ? root.daemon.displayLabel(root.timer) : ""
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.tint(Theme.surfaceVariantText, Qt.rgba(root.frostColor.r, root.frostColor.g, root.frostColor.b, root.frost * 0.6))
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: TP.formatClock(root.remaining)
            font.pixelSize: Math.round(Theme.fontSizeXLarge * 2.6)
            font.weight: Font.Light
            font.features: {
                "tnum": 1
            }
            wrapMode: Text.NoWrap
            // Frozen: the digits turn ice blue.
            color: root.timerState === "ringing" ? Theme.error : Qt.tint(Theme.surfaceText, Qt.rgba(root.frostColor.r, root.frostColor.g, root.frostColor.b, root.frost * 0.85))
            style: root.frost > 0.01 ? Text.Outline : Text.Normal
            styleColor: Qt.rgba(root.frostColor.r, root.frostColor.g, root.frostColor.b, 0.25 * root.frost)

            // Ringing: blinks between 1 and 0.35 every 1.3 s.
            opacity: root.timerState === "ringing" ? Motion.wave(root.fxTime, 1.3, 1, 0.35) : 1
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.timerState === "paused" ? "ac_unit" : (root.timerState === "ringing" ? "alarm" : "notifications")
                size: Theme.iconSizeSmall
                filled: true
                color: root.timerState === "ringing" ? Theme.error : (root.timerState === "paused" ? root.frostColor : Theme.surfaceVariantText)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!root.timer)
                        return "";
                    if (root.timerState === "paused")
                        return "Paused";
                    if (root.timerState === "ringing")
                        return "Done";
                    const end = TP.formatTimeOfDay(root.timer.endAt, root.use24h);
                    return TP.isTomorrow(root.timer.endAt, root.daemon.now) ? "Tomorrow " + end : end;
                }
                font.pixelSize: Theme.fontSizeMedium
                font.features: {
                    "tnum": 1
                }
                color: root.timerState === "ringing" ? Theme.error : (root.timerState === "paused" ? root.frostColor : Theme.surfaceVariantText)
            }
        }
    }
}
