import QtQuick
import qs.Common
import qs.Widgets
import "Journal.js" as Journal
import "../settings/Variants.js" as Variants

// The time journal screen: this week's total, then one of two looks (a glass
// of sand layers, or poured threads), then the privacy line. Built only while
// the screen is open; the week is read once from the daemon when it opens and
// nothing runs afterwards.
Column {
    id: root

    required property var daemon
    // Raw value of the "Time journal view" setting; anything unknown is the default
    property string look: ""
    property bool reducedMotion: false

    readonly property string cleanLook: Variants.clean("journal", look)
    property var entries: []
    property bool loaded: false
    readonly property bool empty: loaded && entries.length === 0
    readonly property var shown: Journal.rows(entries, cleanLook === "threads" ? Journal.THREADS_MAX : Journal.STRATA_MAX)

    spacing: Theme.spacingM

    // One-shot entrance; shorter in Reduce motion
    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: root.reducedMotion ? 150 : 200
        easing.type: Easing.OutCubic
    }
    leftPadding: Theme.spacingL
    rightPadding: Theme.spacingL

    // The daemon may answer after the screen was closed
    property bool alive: true
    Component.onDestruction: alive = false
    Component.onCompleted: daemon.historyThisWeek(e => {
        if (!root.alive)
            return;
        root.entries = e;
        root.loaded = true;
    })

    // The inside width, where everything is laid out
    readonly property real inner: width - leftPadding - rightPadding

    Column {
        width: root.inner
        visible: root.loaded && !root.empty
        StyledText {
            text: "This week"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.NoWrap
        }
        StyledTime {
            text: Journal.duration(Journal.sum(root.entries))
            font.pixelSize: 32
            font.weight: Font.Light
        }
    }

    Column {
        visible: root.empty
        width: root.inner
        topPadding: Theme.spacingL
        bottomPadding: Theme.spacingL
        spacing: Theme.spacingS

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            path: "M4 2.5h8M4 13.5h8M5 2.5c0 3 2.6 3.6 3 5.5c.4-1.9 3-2.5 3-5.5M5 13.5c0-3 2.6-3.6 3-5.5c.4 1.9 3 2.5 3 5.5"
            size: 48
            color: Theme.outline
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No time recorded this week"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Name a timer, for example “25m work”, and its time adds up here."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    // One Loader: only the chosen look exists
    Loader {
        width: root.inner
        active: root.loaded && !root.empty
        visible: active
        sourceComponent: root.cleanLook === "threads" ? threads : strata
    }

    Component {
        id: strata
        Strata {
            shown: root.shown
            reducedMotion: root.reducedMotion
        }
    }

    Component {
        id: threads
        Threads {
            shown: root.shown
            reducedMotion: root.reducedMotion
        }
    }

    // Privacy line and the erase link on one row
    Row {
        width: root.inner
        height: Math.max(44, note.implicitHeight)
        spacing: Theme.spacingS

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            path: "M2.5 3h11v8h-11zM6 13.5h4M5 9c1.5-2.6 4.5-2.6 6 0"
            color: Theme.surfaceVariantText
        }
        StyledText {
            id: note
            width: parent.width - 16 - clear.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            text: "Kept on this machine only. Nothing is sent."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }
        LinkButton {
            id: clear
            objectName: "clear"
            anchors.verticalCenter: parent.verticalCenter
            caption: "Clear the journal"
            underline: true
            textColor: Theme.primary
            enabled: !root.empty
            opacity: root.empty ? 0.38 : 1
            reducedMotion: root.reducedMotion
            onClicked: {
                root.daemon.eraseHistory();
                root.entries = [];
            }
        }
    }
}
