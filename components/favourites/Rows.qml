import QtQuick
import qs.Common
import qs.Widgets
import "../journal"
import "../journal/Paths.js" as Paths

// "Rows": one full-width line per favourite, the duration in bold, the name,
// how many times it was started, and a play mark that goes once it started.
Column {
    id: root

    required property var pins
    property int startedIndex: -1
    property bool reducedMotion: false

    signal chosen(int index)

    spacing: Theme.spacingM

    Repeater {
        model: root.pins

        Rectangle {
            id: line

            required property var modelData
            required property int index
            readonly property bool started: root.startedIndex === index

            x: Theme.spacingM
            width: (parent ? parent.width : 340) - 2 * Theme.spacingM
            height: Math.max(44, text.implicitHeight + 16)
            radius: Theme.cornerRadius
            color: press.pressed || hover.hovered ? Theme.surfaceContainerHighest : "transparent"
            scale: press.pressed && !root.reducedMotion ? 0.97 : 1
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label
            Keys.onReturnPressed: root.chosen(index)
            Keys.onEnterPressed: root.chosen(index)
            Keys.onSpacePressed: root.chosen(index)

            // Focus ring, 2 px, drawn 2 px outside the row
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                visible: line.activeFocus
                radius: line.radius + 2
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
                onTapped: root.chosen(line.index)
            }

            Glyph {
                id: glass
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                path: Paths.glass
                size: 24
                color: Theme.primary
            }
            Column {
                id: text
                anchors.left: glass.right
                anchors.leftMargin: Theme.spacingM
                anchors.right: mark.left
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                // Semibold duration, then the name cut with an ellipsis
                Row {
                    width: parent.width
                    spacing: Theme.spacingXS
                    StyledText {
                        id: dur
                        textFormat: Text.PlainText
                        text: line.modelData.duration
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.surfaceText
                    }
                    StyledText {
                        id: dot
                        text: "\u00b7"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                    ElidedName {
                        width: parent.width - dur.width - dot.width - 2 * parent.spacing
                        text: line.modelData.name
                    }
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: line.started ? "Started" : line.modelData.startedText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
            Glyph {
                id: mark
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: !line.started
                path: Paths.play
                size: 16
                color: Theme.primary
            }
        }
    }
}
