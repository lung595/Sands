import QtQuick
import qs.Common
import qs.Widgets
import "settings"
import "Press.js" as Press

// Shown in the panel when something you tried cannot be done: never a
// silent refusal. One short line says what happened, a second what to do,
// and the GitHub mark opens the guide section that explains it (in your
// browser, on click only; Sands itself never goes online). It fades away
// after a few seconds, or stays while the pointer rests on it.
Rectangle {
    id: note

    property var daemon: null
    // { title, hint, anchor } from Guide.js, null when there is none; a row
    // that owns its message (settings) sets this instead of daemon.note
    property var info: daemon ? daemon.note : null
    // Wider text wraps instead of leaving the panel
    property real maxWidth: 320
    // In a settings row: takes the whole maxWidth and stays until its owner
    // clears it (the hint may hold a command to type)
    property bool pinned: false
    // Room around the text, the side of the guide link, what is left for the text
    readonly property int padX: 12
    readonly property int padY: 8
    readonly property int linkSize: 28
    readonly property real textRoom: maxWidth - 2 * padX - row.spacing - linkSize

    function openGuide() {
        Qt.openUrlExternally(daemon.guideUrl + "#" + (info ? info.anchor : ""));
        if (!pinned)
            daemon.note = null;
    }

    visible: opacity > 0.01
    opacity: info ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: SettingsData.reduceMotion ? 0 : Press.FADE_IN_MS
        }
    }
    width: pinned ? maxWidth : row.width + 2 * padX
    height: row.implicitHeight + 2 * padY
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHighest
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.24)

    // Only runs while a note is shown, and waits while it is pointed at
    Timer {
        running: !!note.info && !note.pinned && !hover.hovered
        interval: Press.PASSING_MS
        onTriggered: note.daemon.note = null
    }
    HoverHandler {
        id: hover
    }

    Row {
        id: row
        x: note.padX
        y: note.padY
        spacing: note.padX
        Column {
            // As wide as the longest line, up to what the panel leaves
            width: note.pinned ? note.textRoom : Math.min(Math.max(title.implicitWidth, hint.implicitWidth), note.textRoom)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            StyledText {
                id: title
                width: parent.width
                wrapMode: Text.WordWrap
                text: note.info ? note.info.title : ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
            StyledText {
                id: hint
                width: parent.width
                wrapMode: Text.WordWrap
                text: note.info ? note.info.hint : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
        // The way to the explanation
        Item {
            id: guideLink
            objectName: "control"
            width: note.linkSize
            height: note.linkSize
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnTab: true
            Accessible.role: Accessible.Link
            Accessible.name: note.info && note.info.link ? note.info.link : "Open the guide"
            Accessible.onPressAction: note.openGuide()
            Keys.onPressed: event => Press.onKey(event, () => note.openGuide())
            // Flush with the link: it has no room for the usual inset
            FocusRing {
                anchors.margins: 0
                border.color: Theme.primary
                visible: guideLink.activeFocus
            }
            GitHubMark {
                anchors.centerIn: parent
                size: 18
                color: link.containsMouse ? Theme.primary : Theme.surfaceVariantText
            }
            MouseArea {
                id: link
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: note.openGuide()
            }
        }
    }
}
