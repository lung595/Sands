import QtQuick

// Round icon button as in the DMS lists (no hover state in a picture).
Item {
    property real buttonSize: 36
    property string iconName: ""
    property color iconColor: "white"
    signal clicked

    implicitWidth: buttonSize
    implicitHeight: buttonSize

    DankIcon {
        anchors.centerIn: parent
        name: parent.iconName
        size: 20
        color: parent.iconColor
    }
    MouseArea {
        anchors.fill: parent
        onClicked: parent.clicked()
    }
}
