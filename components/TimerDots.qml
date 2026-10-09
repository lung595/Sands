import QtQuick
import qs.Common

// Dots: where you are among the timers (each in its color).
Row {
    id: root

    required property var daemon
    required property var ids
    // Id of the timer shown, and its position in `ids`
    required property int currentId
    required property int currentIndex

    signal picked(int id, int dir)

    spacing: 6
    visible: ids.length > 1

    Repeater {
        model: root.ids

        Rectangle {
            id: dot
            required property var modelData
            required property int index
            readonly property bool current: root.currentId === modelData
            readonly property var tm: root.daemon ? root.daemon.find(modelData) : null
            width: current ? 18 : 6
            height: 6
            radius: 3
            color: root.daemon && tm ? root.daemon.colorFor(tm) : Theme.primary
            opacity: current ? 1 : 0.45

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(dot.modelData, dot.index > root.currentIndex ? 1 : -1)
            }
        }
    }
}
