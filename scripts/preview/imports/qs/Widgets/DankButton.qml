import QtQuick

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
    activeFocusOnTab: true
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#D0BCFF"
    }
}
