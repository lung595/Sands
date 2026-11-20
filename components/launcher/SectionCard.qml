import QtQuick
import qs.Common
import qs.Widgets

// One card of the "Timers" row of the launcher, drawn by DMS for each item of
// TimerLauncher.getSectionItems(). DMS sets launcherItem (its item, with what
// Section.js built under `data`), selected and expanded; implicitHeight is the
// height of the row. A plain first version: icon and name, "+N" for the card
// of the hidden timers.
Item {
    id: root

    property var launcherItem: null
    property bool selected: false
    property bool expanded: false

    readonly property var entry: launcherItem ? (launcherItem.data || launcherItem) : ({})
    readonly property string kind: entry.kind || "timer"
    readonly property bool ringing: entry.state === "ringing"

    Accessible.role: Accessible.Button
    Accessible.name: entry.name || ""

    implicitHeight: 56
    implicitWidth: 180

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.cornerRadius
        color: root.selected ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        opacity: root.kind === "favourite" ? 0.7 : 1
        border.width: root.selected ? 2 : 0
        border.color: root.ringing ? Theme.error : Theme.primary

        StyledText {
            visible: root.kind === "more"
            anchors.centerIn: parent
            text: root.entry.name || ""
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Row {
            visible: root.kind !== "more"
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: String(root.entry.icon || "material:timer").replace(/^material:/, "")
                size: Theme.iconSize
                color: root.ringing ? Theme.error : Theme.primary
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSize - Theme.spacingS

                StyledText {
                    width: parent.width
                    text: root.entry.name || ""
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeMedium
                    color: root.ringing ? Theme.error : Theme.surfaceText
                }
                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: root.entry.comment || ""
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
