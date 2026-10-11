import QtQuick
import qs.Common
import qs.Widgets
import "../daemon/PlainText.js" as PlainText
import "DuneMotion.js" as Motion
import "DuneStyles.js" as Styles

// The Rising dune band: the scene in a Loader that is inactive at rest, the
// 30 Hz Timer that feeds it and the legend. Cost rules: nothing exists until
// `shown`, the Timer stops by itself on the last step (then zero repaint) and
// no QML animation runs. Pure of windows, so the layer host and the tests use
// the same item.
Item {
    id: band

    // Alert on screen: false at rest, so no scene, no Timer
    property bool shown: false
    // Saved style key
    property string style: Styles.DEFAULT
    // Name of the timer named in the legend, and the reason part after the dot
    property string name: ""
    // The name as drawn: a typed em or en dash becomes a plain hyphen
    readonly property string shownName: PlainText.plain(name) !== "" ? PlainText.plain(name) : "Timer"
    property string reason: "Sound is muted"
    property bool reduceMotion: false
    // New seed per alert, set by the host when the alert opens
    property int seed: 1

    // The legend is the only part that takes clicks (Stop)
    readonly property alias legend: legendBox
    readonly property real nameDrawn: nameText.width
    readonly property real nameFull: nameText.implicitWidth
    readonly property bool animating: tick.running
    // Present from the first step until the 150 ms fade out has ended
    readonly property bool sceneLoaded: sceneLoader.active
    readonly property var duneState: _state
    // Legend appears within 0.4 s of the first step, at once under Reduce motion
    readonly property bool legendVisible: shown && (_state.done || _state.step >= 12)

    signal stopRequested

    // One scene file per style. Only Last grains exists yet, so wind (the
    // default, D492) and wave show it until their stories add their entry.
    readonly property var scenes: ({
            "grains": "GrainsScene.qml"
        })
    readonly property string drawn: scenes[Styles.resolve(style)] ? Styles.resolve(style) : "grains"

    property var _state: Motion.posed(drawn)

    onShownChanged: _restart()
    onReduceMotionChanged: _restart()

    function _restart() {
        _state = shown ? Motion.stateAt(drawn, 0, seed, reduceMotion) : Motion.posed(drawn);
    }

    // One-shot 150 ms fade in and out (not looping): the Loader is emptied once
    // the fade out has ended
    Item {
        id: content
        anchors.fill: parent
        opacity: band.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Loader {
            id: sceneLoader
            anchors.fill: parent
            active: band.shown || content.opacity > 0
            source: Qt.resolvedUrl(band.scenes[band.drawn])
            onLoaded: {
                item.duneState = Qt.binding(() => band._state);
                item.seed = Qt.binding(() => band.seed);
                item.capLeft = Qt.binding(() => legendBox.x);
                item.capRight = Qt.binding(() => legendBox.x + legendBox.width);
                item.capTop = Qt.binding(() => legendBox.y);
            }
        }

        // No card: two texts on the sand, on-primary, 12 px above the bottom
        // edge. The whole 44 px strip under them takes the click (Stop).
        Item {
            id: legendBox
            visible: band.legendVisible
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM - (height - captionRow.height) / 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - Theme.spacingL * 2, 2 * Math.ceil((nameText.implicitWidth + tail.implicitWidth) / 2) + Theme.spacingL * 2)
            height: 44

            // The tail follows the drawn (possibly elided) name, so no gap opens
            Item {
                id: captionRow
                anchors.centerIn: parent
                readonly property real avail: Math.min(parent.width, nameText.implicitWidth + tail.implicitWidth)
                width: nameText.contentWidth + tail.implicitWidth
                height: nameText.implicitHeight

                StyledText {
                    id: nameText
                    width: Math.min(implicitWidth, Math.max(0, captionRow.avail - tail.implicitWidth))
                    text: band.shownName
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.onPrimary
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
                StyledText {
                    id: tail
                    x: nameText.contentWidth
                    text: " is done" + (band.reason !== "" ? " · " + band.reason : "")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.onPrimary
                    wrapMode: Text.NoWrap
                    elide: Text.ElideNone
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: band.stopRequested()
            }
        }
    }

    // Steps counted by the Timer, so a stop and a replay give the same frames
    Timer {
        id: tick
        interval: Math.round(1000 / Motion.STEP_HZ)
        repeat: true
        running: band.shown && !band._state.done
        onTriggered: band._state = Motion.stateAt(band.drawn, band._state.step + 1, band.seed, band.reduceMotion)
    }
}
