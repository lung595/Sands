import QtQuick
import qs.Common
import qs.Widgets

// The link under the panel that opens the time journal, and brings the timers back.
Item {
    id: root

    property bool open: false
    signal toggled

    height: 44

    StyledText {
        anchors.centerIn: parent
        text: root.open ? "Back to timers" : "This week"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.NoWrap
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
