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
    leftPadding: Theme.spacingL
    rightPadding: Theme.spacingL

    Component.onCompleted: daemon?.historyThisWeek(e => {
        root.entries = e;
        root.loaded = true;
    })

    // The inside width, where everything is laid out
    readonly property real inner: width - leftPadding - rightPadding

    Column {
        width: root.inner
        visible: root.loaded
        StyledText {
            text: "This week"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.NoWrap
        }
        StyledTime {
            visible: !root.empty
            text: Journal.duration(root.entries.reduce((a, e) => a + e.ms, 0))
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

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "hourglass_empty"
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

    Column {
        width: root.inner
        spacing: 0

        Row {
            width: parent.width
            spacing: Theme.spacingS
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "computer"
                size: Theme.iconSizeSmall
                color: Theme.surfaceVariantText
            }
            StyledText {
                width: parent.width - Theme.iconSizeSmall - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Kept on this machine only. Nothing is sent."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Item {
            width: parent.width
            height: 44
            opacity: root.empty ? 0.38 : 1

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Theme.spacingS
                text: "Clear the journal"
                font.pixelSize: Theme.fontSizeMedium
                font.underline: true
                color: Theme.primary
                wrapMode: Text.NoWrap
            }
            MouseArea {
                anchors.fill: parent
                enabled: !root.empty
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.daemon.eraseHistory();
                    root.entries = [];
                }
            }
        }
    }
}
