import QtQuick
import qs.Common

// What the Edge halo draws on one screen: the 4 px rim and the legend pill.
// Display only; HaloScene owns the window and the steps.
Item {
    id: root

    // Opacity 0..1 of the rim and the legend
    required property real level
    required property string legend
    readonly property alias pill: pill

    // The name comes first so that only it is elided; " is done · reason" is the information
    readonly property int _split: legend.lastIndexOf(" is done")
    readonly property string _name: _split < 0 ? legend : legend.slice(0, _split)
    readonly property string _tail: _split < 0 ? "" : legend.slice(_split)

    signal stopRequested

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 4
        border.color: Theme.primary
        opacity: root.level
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingL
        width: Math.min(nameText.implicitWidth + tailText.implicitWidth + Theme.spacingL * 2, parent.width - Theme.spacingL * 2)
        height: nameText.implicitHeight + Theme.spacingM * 2
        radius: height / 2
        color: Theme.surfaceContainerHigh
        // Full at the trough of a beat (0.5) so the legend keeps its contrast
        opacity: Math.min(1, root.level * 2)

        // Hover and pressed layer: set by state, no animation
        Rectangle {
            anchors.fill: parent
            radius: pill.radius
            color: Theme.surfaceText
            opacity: tap.pressed ? 0.12 : (tap.containsMouse ? 0.08 : 0)
        }

        Row {
            anchors.centerIn: parent
            Text {
                id: nameText
                width: Math.min(implicitWidth, pill.width - Theme.spacingL * 2 - tailText.implicitWidth)
                elide: Text.ElideRight
                text: root._name
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }
            Text {
                id: tailText
                text: root._tail
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }

        MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stopRequested()
        }
    }
}
