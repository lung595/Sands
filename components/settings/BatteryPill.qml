import QtQuick
import qs.Common
import qs.Widgets

// The three-level battery-use chip of a costly setting. The level is read from
// the number of grains (1, 2, 3) and from the words, never from colour alone;
// the text keeps the theme text colour on the raised surface (contrast proven in
// the approved page), only the grains carry the tone.
Rectangle {
    id: root

    // "high" | "some" | "light" (see Sections.LEVELS)
    required property string level

    readonly property int grains: level === "high" ? 3 : (level === "some" ? 2 : 1)
    readonly property color tone: level === "high" ? Theme.error : (level === "some" ? Theme.warning : Theme.primary)
    readonly property string text: level === "high" ? "High battery use" : (level === "some" ? "Some battery use" : "Light on battery")

    implicitWidth: row.implicitWidth + Theme.spacingS + Theme.spacingM
    implicitHeight: Math.max(24, label.implicitHeight + Theme.spacingXS)
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    Row {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: root.grains

                delegate: Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: root.tone
                }
            }
        }

        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.surfaceText
        }
    }
}
