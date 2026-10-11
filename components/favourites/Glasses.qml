import QtQuick
import qs.Common
import qs.Widgets
import "../journal"
import "../journal/Paths.js" as Paths

// "Three glasses": a row of up to three tiles, a big glass, the duration and
// the name. A started tile turns its glass over once (300 ms) and says "Started".
Row {
    id: root

    required property var pins
    property int startedIndex: -1
    property bool reducedMotion: false

    signal chosen(int index)

    x: Theme.spacingM
    spacing: Theme.spacingS
    readonly property real tileWidth: Math.floor(((parent ? parent.width : 340) - 2 * Theme.spacingM - 2 * spacing) / 3)

    Repeater {
        model: root.pins

        Rectangle {
            id: tile

            required property var modelData
            required property int index
            readonly property bool started: root.startedIndex === index

            width: root.tileWidth
            height: Math.max(96, col.implicitHeight + 24)
            radius: Theme.cornerRadius
            color: press.pressed || hover.hovered ? Theme.surfaceContainerHighest : "transparent"
            border.width: 1
            border.color: Theme.outline
            scale: press.pressed && !root.reducedMotion ? 0.97 : 1
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label
            Keys.onReturnPressed: root.chosen(index)
            Keys.onEnterPressed: root.chosen(index)
            Keys.onSpacePressed: root.chosen(index)

            // Focus ring, 2 px, drawn 2 px outside the tile
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                visible: tile.activeFocus
                radius: tile.radius + 2
                color: "transparent"
                border.width: 2
                border.color: Theme.primary
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: press
                onTapped: root.chosen(tile.index)
            }

            Column {
                id: col
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: Theme.spacingXS

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    path: Paths.glass
                    size: 32
                    color: Theme.primary
                    rotation: tile.started && !root.reducedMotion ? 180 : 0
                    Behavior on rotation {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: tile.modelData.duration
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    font.features: {
                        "tnum": 1
                    }
                    color: Theme.surfaceText
                }
                // Cut with an ellipsis; the full name is the tooltip
                ElidedName {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.started ? "Started" : tile.modelData.name
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
