import QtQuick
import QtQuick.Shapes
import qs.Common
import "../"
import "../Press.js" as Press

// The "Copy report" button: the quiet outline button of the settings rows,
// plus the check that appears once the report is copied and the heap that
// settles at its foot. It only says it was pressed (`clicked`); the row
// decides what a press does.
OutlineButton {
    id: button

    property bool copied: false
    // The label is dimmed while the report is being built or copied
    property bool collecting: false
    // Reduce motion: no scale, the heap appears at its full height
    property bool still: false
    // Wide enough for its longest label ("Collecting...")
    readonly property int labelWidth: 112
    // How much of the primary colour fills it once copied
    readonly property real copiedTint: 0.14
    // The heap: its height, and the share of it shown when it starts to rise
    readonly property int heapHeight: 8
    readonly property real heapStart: 0.3
    // The heap and its fade take a little longer to settle than a plain fade
    readonly property int settleMs: 200
    readonly property int pressMs: 100
    readonly property real pressedScale: 0.97
    // The check: its side and the width of its round stroke
    readonly property int checkSize: 16
    readonly property real checkStroke: 1.5

    // A low dune as wide as `w`: a flat foot one pixel thick, the crest a
    // little left of the middle, one pixel under the top
    function heapPath(w) {
        const foot = heapHeight - 1;
        return "M0 " + heapHeight + "V" + foot + "C" + w * 0.22 + " " + foot + " " + w * 0.3 + " 1 " + w * 0.42 + " 1S" + w * 0.66 + " " + (foot - 1) + " " + w + " " + foot + "V" + heapHeight + "Z";
    }

    width: labelWidth
    height: Press.TARGET
    spacing: Theme.spacingXS
    textColor: collecting ? Theme.surfaceVariantText : Theme.surfaceText
    cursorShape: Qt.PointingHandCursor
    color: copied ? Theme.withAlpha(Theme.primary, copiedTint) : (hovered ? Theme.surfaceContainerHigh : "transparent")
    border.color: copied ? Theme.primary : Theme.outline
    scale: pressed && !still ? pressedScale : 1
    Accessible.onPressAction: button.clicked()
    // Return and Space are the outline button's; the keypad Enter presses too
    Keys.onEnterPressed: button.clicked()
    // A click leaves the focus on the button, as a key press finds it
    onClicked: button.forceActiveFocus()

    Behavior on color {
        ColorAnimation {
            duration: Press.FADE_IN_MS
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: button.pressMs
            easing.type: Easing.OutCubic
        }
    }

    FocusRing {
        border.color: Theme.primary
        visible: button.activeFocus
    }

    // The heap that settles at the foot once the report is copied
    Shape {
        id: heap
        width: parent.width - 2
        height: button.heapHeight
        x: 1
        y: parent.height - height - 1
        visible: opacity > 0.01
        opacity: button.copied ? 1 : 0
        transform: Scale {
            origin.y: heap.height
            yScale: button.still || button.copied ? 1 : button.heapStart
            Behavior on yScale {
                NumberAnimation {
                    duration: button.copied ? button.settleMs : Press.FADE_OUT_MS
                    easing.type: Easing.OutCubic
                }
            }
        }
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity {
            NumberAnimation {
                duration: button.copied ? button.settleMs : Press.FADE_OUT_MS
                easing.type: Easing.OutCubic
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Theme.primary
            PathSvg {
                path: button.heapPath(heap.width)
            }
        }
    }

    // The check before the label, only once copied (drawn on a 16 px grid)
    lead: Shape {
        width: button.checkSize
        height: button.checkSize
        anchors.verticalCenter: parent.verticalCenter
        visible: opacity > 0.01
        opacity: button.copied ? 1 : 0
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity {
            NumberAnimation {
                duration: button.copied ? Press.FADE_IN_MS : Press.FADE_OUT_MS
            }
        }
        ShapePath {
            strokeWidth: button.checkStroke
            strokeColor: Theme.primary
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M3 8.5L6.5 12L13 4.5"
            }
        }
    }
}
