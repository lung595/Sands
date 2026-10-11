import QtQuick
import qs.Common
import qs.Widgets
import ".."

// The short reason a field refused its input, beside the field (value 10),
// with the GitHub mark that opens the guide section on click only. Hidden
// when there is no text. Wraps at the width it is given.
Item {
    id: root

    property string text: ""
    property string url: ""

    visible: text !== ""
    width: parent.width
    implicitHeight: visible ? Math.max(message.implicitHeight, 44) : 0

    StyledText {
        id: message
        anchors.left: parent.left
        anchors.right: mark.left
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.error
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    Item {
        id: mark
        objectName: "control"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        activeFocusOnTab: root.url !== ""
        Accessible.role: Accessible.Button
        Accessible.name: "Open the guide section"
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                area.clicked(null);
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingXS
            radius: Theme.cornerRadius
            color: area.containsMouse ? Theme.surfaceContainerHighest : "transparent"
            border.width: mark.activeFocus ? 2 : 0
            border.color: Theme.primary
        }
        GitHubMark {
            anchors.centerIn: parent
            size: 20
            color: Theme.surfaceVariantText
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.url !== "")
                Qt.openUrlExternally(root.url)
        }
    }
}
