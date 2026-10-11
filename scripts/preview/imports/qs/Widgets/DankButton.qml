import QtQuick
import qs.Common
import qs.Widgets

// Preview stand-in sized like the DMS button: text, icon and padding, 40 px high.
Item {
    id: root
    objectName: "control"
    property string text: ""
    property string iconName: ""
    signal clicked
    TextMetrics {
        id: metrics
        text: root.text
        font.pixelSize: 14
    }
    implicitWidth: metrics.width + (iconName !== "" ? 24 + 8 : 0) + 2 * 16
    implicitHeight: 40
    width: implicitWidth
    height: implicitHeight
    // Lets the overlap test see a label cut short
    readonly property bool truncated: label.truncated
    activeFocusOnTab: true
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.primary
    }
    DankIcon {
        id: glyph
        visible: root.iconName !== ""
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: root.iconName
        size: 24
        color: Theme.surface
    }
    StyledText {
        id: label
        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: glyph.visible ? 8 : 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.surface
        wrapMode: Text.NoWrap
    }
    // Tests click it like the real button; a disabled one ignores the click
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
