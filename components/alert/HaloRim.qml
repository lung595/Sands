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
        width: Math.min(label.implicitWidth + Theme.spacingL * 2, parent.width - Theme.spacingL * 2)
        height: label.implicitHeight + Theme.spacingM * 2
        radius: height / 2
        color: Theme.surfaceContainer
        opacity: root.level

        Text {
            id: label
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.legend
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.stopRequested()
        }
    }
}
