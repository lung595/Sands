import QtQuick
import qs.Common
import qs.Widgets

// Quiet button of the settings rows: transparent, 1 px outline, 44 px high (the
// touch target). Filled primary stays for the one main action of a screen.
Rectangle {
    id: root
    objectName: "control"

    property string text: ""
    property string iconName: ""
    // For a button that says more than its label ("Copy report"): the colour
    // of the label, what is drawn before it and how close, the pointer
    property color textColor: Theme.surfaceText
    property alias lead: leadSlot.data
    property alias spacing: content.spacing
    property alias cursorShape: area.cursorShape
    readonly property alias pressed: area.pressed
    readonly property alias hovered: area.containsMouse

    signal clicked

    implicitWidth: content.implicitWidth + Theme.spacingM * 2
    implicitHeight: 44
    radius: Theme.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.outline
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    // Lets the overlap test see a label cut short
    readonly property bool truncated: label.truncated

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Row {
            id: leadSlot
            anchors.verticalCenter: parent.verticalCenter
        }
        DankIcon {
            visible: root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            size: 20
            color: Theme.surfaceText
        }
        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.textColor
            font.pixelSize: Theme.fontSizeMedium
            wrapMode: Text.NoWrap
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
