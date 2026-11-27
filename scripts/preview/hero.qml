import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Window
import qs.Common
import qs.Services
import qs.Widgets
import "../../components"
import "mock"

// The README's cover picture (and GitHub's social preview): 1280 x 640, with
// the real bar pill and the real panel on made-up timers, in a warm sand
// palette (a DMS theme generated from a desert wallpaper).
// Usage: TZ=UTC QT_SCALE_FACTOR=2 QT_QPA_PLATFORM=offscreen qml-qt6 -I imports hero.qml -- <out.png>
// (twice the size, sharp on HiDPI screens). The clock is frozen, so the
// picture is the same on every run. "plain" (before <out.png>) leaves the
// words out and keeps DMS's default purple, 760 x 640: the plugin registry
// wraps the picture in its own card with the name and the description.
Window {
    id: win
    readonly property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    readonly property bool plain: Qt.application.arguments.indexOf("plain") >= 0
    width: plain ? 760 : 1280
    height: 640
    visible: true
    color: Theme.surface

    readonly property int mm: 60000

    // Newer DMS builds embed the shell: the font is then read from
    // ~/.local/share/fonts, like the icon font (see imports/qs/Widgets/DankIcon.qml)
    readonly property bool sansInstalled: Qt.fontFamilies().indexOf("Google Sans Flex") >= 0
    FontLoader {
        id: sans
        source: win.sansInstalled ? "" : "file:///usr/share/quickshell/dms/DCommon/assets/fonts/google-sans-flex/GoogleSansFlex.ttf"
    }
    readonly property string family: sansInstalled ? "Google Sans Flex" : sans.status === FontLoader.Ready ? sans.name : "Noto Sans"

    FakeDaemon {
        id: daemon
        accent: win.plain ? "#D0BCFF" : "#F0BF6C"
        favourites: [{ "name": "Tea", "count": 14, "ms": 4 * win.mm }, { "name": "Pasta", "count": 9, "ms": 12 * win.mm }, { "name": "Focus", "count": 6, "ms": 25 * win.mm }]
    }

    property bool ready: false
    Component.onCompleted: {
        if (plain)
            return start();
        // Material dark scheme from a sand seed (#C89B4A)
        Theme.primary = "#F0BF6C";
        Theme.primaryText = "#422C00";
        Theme.onPrimary = "#422C00";
        Theme.onError = "#690005";
        Theme.primaryContainer = "#5E4100";
        Theme.onPrimaryContainer = "#FFDEAC";
        Theme.error = "#FFB4AB";
        Theme.outline = "#9D8F7C";
        Theme.outlineVariant = "#4F4536";
        Theme.surface = "#17130D";
        Theme.surfaceContainer = "#241F17";
        Theme.surfaceContainerHigh = "#2F2921";
        Theme.surfaceContainerHighest = "#3A342B";
        Theme.surfaceText = "#ECE1D3";
        Theme.surfaceVariantText = "#D4C4AE";
        Theme.widgetTextColor = "#ECE1D3";
        Theme.surfaceTextHover = Qt.rgba(0.93, 0.88, 0.83, 0.08);
        start();
    }
    function start() {
        SettingsData.reduceMotion = true;
        daemon.load([["running", "Pasta", 20 * mm, 12 * mm + 34000, 0], ["running", "Laundry", 45 * mm, 31 * mm, 1]]);
        PluginService.pluginDaemonInstances = {
            "smartTimer": daemon
        };
        ready = true;
    }

    // grabToImage leaves out the window's own colour
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    // Warm light behind the panel, like sun on sand
    Rectangle {
        id: glow
        width: 520
        height: 520
        radius: width / 2
        x: sheet.x + sheet.width / 2 - width / 2
        y: sheet.y + sheet.height / 2 - height / 2
        color: win.plain ? "#6750A4" : "#C8862E"
        opacity: 0.4
        visible: false
    }
    MultiEffect {
        source: glow
        anchors.fill: glow
        autoPaddingEnabled: true
        blurEnabled: true
        blurMax: 64
        blurMultiplier: 4
        blur: 1
        opacity: glow.opacity
    }

    // Dunes along the bottom: three ridges, the farthest the faintest
    Repeater {
        model: [{ "y": 470, "a": 0.05, "k": 0 }, { "y": 520, "a": 0.08, "k": 1 }, { "y": 575, "a": 0.12, "k": 2 }]
        Shape {
            id: dune
            readonly property real b: modelData.y
            readonly property real s: modelData.k * 170
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.withAlpha(Theme.primary, modelData.a * 2)
                strokeWidth: 1.2
                fillGradient: LinearGradient {
                    x1: 0; y1: modelData.y - 60
                    x2: 0; y2: win.height
                    GradientStop { position: 0; color: Theme.withAlpha(Theme.primary, modelData.a) }
                    GradientStop { position: 1; color: Theme.withAlpha(Theme.primary, 0) }
                }
                startX: 0
                startY: dune.b
                PathCubic { x: 520 + dune.s; y: dune.b - 40; control1X: 180 + dune.s; control1Y: dune.b - 90; control2X: 340 + dune.s; control2Y: dune.b + 30 }
                PathCubic { x: 1280; y: dune.b - 30; control1X: 760 + dune.s; control1Y: dune.b - 120; control2X: 1020; control2Y: dune.b + 40 }
                PathLine { x: 1280; y: win.height }
                PathLine { x: 0; y: win.height }
            }
        }
    }

    // Grains of sand drifting in the air, always in the same places
    Repeater {
        model: 110
        Rectangle {
            readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12543.137) % 1
            readonly property real r3: Math.abs(Math.sin(index * 39.425) * 24634.633) % 1
            x: r1 * win.width
            y: r2 * win.height
            width: r3 > 0.85 ? 2.4 : 1.4
            height: width
            radius: width / 2
            color: Theme.primary
            opacity: 0.08 + r3 * 0.3
        }
    }

    // Left: what it is, in a few words
    Column {
        id: pitch
        visible: !win.plain
        x: 80
        anchors.verticalCenter: parent.verticalCenter
        width: 520
        spacing: 0

        Rectangle {
            width: chipRow.width + 28
            height: 34
            radius: height / 2
            color: Theme.withAlpha(Theme.primary, 0.14)
            border.color: Theme.withAlpha(Theme.primary, 0.28)
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 8
                DankIcon {
                    name: "extension"
                    size: 18
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Plugin for DankMaterialShell"
                    color: Theme.primary
                    font.family: win.family
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { width: 1; height: 22 }

        Text {
            text: "Sands"
            color: Theme.primary
            font.family: win.family
            font.pixelSize: 76
            font.weight: Font.Bold
            font.letterSpacing: -1.5
        }

        Item { width: 1; height: 8 }

        Text {
            width: parent.width
            text: "An hourglass timer that lives in your bar. Type a duration in the launcher, watch the sand fall."
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            font.family: win.family
            font.pixelSize: 20
            lineHeight: 1.25
        }

        Item { width: 1; height: 26 }

        // The launcher line, as you would type it
        Rectangle {
            width: typed.width + 36
            height: 44
            radius: 22
            color: Theme.surfaceContainerHigh
            border.color: Theme.withAlpha(Theme.outline, 0.35)
            Row {
                id: typed
                anchors.centerIn: parent
                spacing: 10
                DankIcon {
                    name: "search"
                    size: 20
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "timer 20 min pasta"
                    color: Theme.surfaceText
                    font.family: "monospace"
                    font.pixelSize: 17
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 2
                    height: 20
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { width: 1; height: 28 }

        Column {
            spacing: 14
            Repeater {
                model: [{ "icon": "hourglass_bottom", "text": "Sand synced by volume to the time left" },
                        { "icon": "ac_unit", "text": "Pause freezes it, restart flips it over" },
                        { "icon": "timer", "text": "Several named timers, each with its color" },
                        { "icon": "bar_chart", "text": "A weekly journal of where your time went" }]
                Row {
                    spacing: 14
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: Theme.withAlpha(Theme.primary, 0.14)
                        DankIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: 19
                            color: Theme.primary
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: Theme.surfaceText
                        font.family: win.family
                        font.pixelSize: 17
                    }
                }
            }
        }

        Item { width: 1; height: 30 }

        Row {
            spacing: 8
            DankIcon {
                name: "shield_lock"
                size: 17
                color: Theme.outline
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "No network, no telemetry  ·  English and French  ·  MIT"
                color: Theme.outline
                font.family: win.family
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Loader {
        id: host
        active: win.ready
        source: "../../TimerWidget.qml"
        // Untyped on purpose: the host stand-in is only known at run time
        readonly property var widget: item
    }

    // Right: the bar with the pill, and the popout below it, the way the
    // shell opens it, scaled down to fit the cover
    readonly property real panelScale: 0.68

    Rectangle {
        id: bar
        anchors.horizontalCenter: sheet.horizontalCenter
        y: 20
        width: sheet.width + 80
        height: 40
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.18)

        Loader {
            anchors.centerIn: parent
            active: host.item !== null
            sourceComponent: host.widget ? host.widget.horizontalBarPill : null
        }
    }

    RectangularShadow {
        anchors.fill: sheet
        radius: sheet.radius
        blur: 48
        spread: 0
        offset.y: 18
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    Rectangle {
        id: sheet
        x: win.plain ? (win.width - width) / 2 : 830
        y: bar.y + bar.height + 12
        width: 400 * win.panelScale
        height: panelLoader.height * win.panelScale
        radius: 20 * win.panelScale
        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.22)
        clip: true

        Loader {
            id: panelLoader
            width: 400
            scale: win.panelScale
            transformOrigin: Item.TopLeft
            active: host.item !== null
            sourceComponent: host.widget ? host.widget.popoutContent : null
        }
    }

    Timer {
        interval: 1500
        running: win.ready
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
