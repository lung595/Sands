import QtQuick
import qs.Common
import qs.Widgets

// The left rail: one entry per section (logo + name). The open section is
// marked by a heap of sand that settles under its logo, one short transition
// and nothing running at rest.
Column {
    id: root

    // [{id, label, icon}] in rail order
    required property var sections
    property string current: ""
    signal picked(string id)

    spacing: 4

    Repeater {
        model: root.sections

        delegate: Rectangle {
            id: entry

            required property var modelData
            readonly property bool open: modelData.id === root.current

            width: parent.width
            height: 40
            radius: Theme.cornerRadius
            color: open ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (hover.hovered ? Theme.surfaceContainerHigh : "transparent")
            objectName: "control"

            Behavior on color {
                enabled: !SettingsData.reduceMotion
                ColorAnimation {
                    duration: hover.hovered ? 150 : 80
                }
            }

            HoverHandler {
                id: hover
            }
            TapHandler {
                onTapped: root.picked(entry.modelData.id)
            }

            // The heap: flat when closed, settled under the logo when open
            Rectangle {
                id: dune
                width: 20
                height: 6
                radius: 3
                x: 14
                y: entry.height - height - 4
                color: Theme.primary
                opacity: entry.open ? 0.9 : 0
                transformOrigin: Item.Bottom
                scale: 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: SettingsData.reduceMotion ? 150 : 180
                    }
                }
            }

            DankIcon {
                id: logo
                name: entry.modelData.icon
                size: 20
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                color: entry.open ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.left: logo.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.label
                font.pixelSize: Theme.fontSizeMedium
                font.weight: entry.open ? Font.DemiBold : Font.Normal
                color: entry.open ? Theme.surfaceText : Theme.surfaceVariantText
                elide: Text.ElideRight
            }
        }
    }
}
