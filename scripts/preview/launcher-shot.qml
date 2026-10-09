import QtQuick
import QtQuick.Window
import qs.Widgets
import "../../TimeParser.js" as TP
import "../../Preview.js" as Preview

// Offscreen picture of the launcher row for docs/images/launcher.png: the real
// parser and preview lines (what TimerLauncher builds) answer a made-up query,
// drawn inside a stand-in of the DMS launcher. The clock is a fixed instant,
// so "ends 12:25" never depends on the machine.
// Usage: TZ=UTC QT_QPA_PLATFORM=offscreen qml-qt6 -I imports launcher-shot.qml -- <out.png>
Window {
    id: win

    readonly property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    readonly property string query: "timer 25 min pasta"
    // Olive palette of the original picture, so the guide keeps its look
    readonly property color bg: "#1f2017"
    readonly property color accent: "#8e9b38"
    readonly property color text: "#e6e3d3"
    readonly property color muted: "#b9b7a6"
    property var item: ({
            name: "",
            comment: ""
        })

    width: 732
    height: 198
    visible: true

    Rectangle {
        anchors.fill: parent
        color: win.bg
    }

    Component.onCompleted: {
        const now = Date.UTC(2026, 9, 9, 12, 0, 0);
        const r = TP.parse(win.query, now, {
            keyword: false
        })[0];
        win.item = {
            name: Preview.previewLine(r, now, true),
            comment: Preview.ringsLine(r, now, true)
        };
    }

    // Search field
    Rectangle {
        x: 8
        y: 8
        width: parent.width - 16
        height: 60
        radius: 18
        color: "transparent"
        border.width: 3
        border.color: win.accent

        DankIcon {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 30
            color: win.accent
        }
        StyledText {
            id: typed
            x: 70
            anchors.verticalCenter: parent.verticalCenter
            text: win.query
            font.pixelSize: 22
            color: win.text
        }
        Rectangle {
            x: typed.x + typed.implicitWidth + 4
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 28
            color: win.text
        }
        DankIcon {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            name: "close"
            size: 20
            color: win.muted
        }
    }

    // Section header
    DankIcon {
        x: 14
        y: 82
        name: "timer"
        size: 20
        color: win.muted
    }
    StyledText {
        x: 46
        y: 82
        height: 20
        text: "Sands"
        font.pixelSize: 16
        color: win.muted
    }
    StyledText {
        x: 112
        y: 82
        height: 20
        text: "1"
        font.pixelSize: 16
        color: Qt.rgba(win.muted.r, win.muted.g, win.muted.b, 0.6)
    }

    // The result row
    Rectangle {
        x: 8
        y: 118
        width: parent.width - 16
        height: 90
        radius: 16
        color: "#2d3117"

        DankIcon {
            x: 28
            y: 14
            name: "timer"
            size: 36
            color: win.text
        }
        StyledText {
            x: 88
            y: 12
            width: 480
            height: 30
            text: win.item.name
            font.pixelSize: 22
            color: win.text
        }
        StyledText {
            x: 88
            y: 42
            width: 480
            height: 24
            text: win.item.comment
            font.pixelSize: 17
            color: win.muted
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 62
            height: 28
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.1)

            StyledText {
                anchors.centerIn: parent
                text: "Plugin"
                font.pixelSize: 14
                color: win.muted
            }
        }
    }

    Timer {
        interval: 600
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
