import QtQuick
import qs.Common
import "ReportRow.js" as Words
import "../"
import "../Press.js" as Press

// The GitHub mark beside "Copy report": a link that only says it was pressed
// (click, Enter or Space). The row opens the address.
Item {
    id: mark

    // Drawn in the primary colour (the report has just been copied)
    property bool active: false
    // Focused or pointed at: the row shows the label of the mark
    readonly property bool labelled: activeFocus || area.containsMouse
    readonly property bool lit: active || labelled

    signal activated

    objectName: "control"
    width: Press.TARGET
    height: Press.TARGET
    activeFocusOnTab: true
    Accessible.role: Accessible.Link
    Accessible.name: Words.MARK_NAME
    Accessible.onPressAction: mark.activated()
    Keys.onPressed: event => Press.onKey(event, () => mark.activated())

    FocusRing {
        border.color: Theme.primary
        visible: mark.activeFocus
    }
    GitHubMark {
        anchors.centerIn: parent
        size: Press.MARK_SIZE
        color: mark.lit ? Theme.primary : Theme.surfaceVariantText
        Behavior on color {
            ColorAnimation {
                duration: mark.lit ? Press.FADE_IN_MS : Press.FADE_OUT_MS
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mark.activated()
    }
}
