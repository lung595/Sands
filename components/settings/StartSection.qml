import QtQuick
import qs.Common
import qs.Widgets
import "../../Guide.js" as Guide

// "Getting started": the widget must be in a bar, then four first steps.
// The settings open here while the widget is in no bar (Placement.js). It
// only explains; it never writes DMS's layout.
Column {
    id: root

    // True when a bar already holds the Sands widget
    required property bool inBar
    // Found by search under this key, so a pick has a block to highlight
    readonly property string settingKey: "gettingStarted"

    width: parent.width
    spacing: Theme.spacingM

    // The one thing people miss: without the widget there is nothing to see
    Rectangle {
        width: parent.width
        height: callout.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: root.inBar ? Theme.withAlpha(Theme.primary, 0.5) : Theme.withAlpha(Theme.error, 0.6)

        Row {
            id: callout
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            DankIcon {
                id: mark
                name: root.inBar ? "check_circle" : "priority_high"
                size: 20
                color: root.inBar ? Theme.primary : Theme.error
            }
            SettingLabel {
                width: parent.width - mark.width - parent.spacing
                title: root.inBar ? "Sands is in your bar" : "Add Sands to your bar first"
                description: root.inBar ? "The pill shows there while a timer runs." : "Turning the plugin on is not enough: the timer only shows from the Sands widget in a bar. Without it, timers still ring, but you never see them count down."
            }
        }
    }

    Repeater {
        model: [
            {
                "title": "Add the widget to a bar",
                "text": "DMS Settings → Bar widgets → Add, then pick Sands. The center of the bar looks best."
            },
            {
                "title": "Start a timer",
                "text": "Open the launcher and type a duration, with a name if you like: timer 20 min pasta · 1h30 oven · at 6pm."
            },
            {
                "title": "Watch the pill",
                "text": "It only appears while a timer runs, so an empty spot right after adding the widget is normal."
            },
            {
                "title": "Click the pill",
                "text": "The hourglass opens: pause freezes the sand, restart flips it. On the pill, right click pauses, scroll adds or removes a minute, middle click cancels."
            }
        ]

        delegate: Row {
            id: step
            required property var modelData
            required property int index

            width: root.width
            spacing: Theme.spacingS

            Rectangle {
                id: badge
                width: 24
                height: 24
                radius: 12
                color: Theme.primaryContainer
                StyledText {
                    anchors.centerIn: parent
                    text: step.index + 1
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.onPrimaryContainer
                }
            }
            SettingLabel {
                width: parent.width - badge.width - parent.spacing
                title: step.modelData.title
                description: step.modelData.text
            }
        }
    }

    DankButton {
        text: "Open the full guide"
        iconName: "menu_book"
        onClicked: Qt.openUrlExternally(Guide.URL)
    }
}
