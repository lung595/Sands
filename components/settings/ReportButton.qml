import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../Press.js" as Press

// The "Copy report" button: its label, the check that appears once the report
// is copied and the heap that settles at its foot. It only says it was
// pressed; the row decides what a press does.
Rectangle {
    id: button

    property string label: ""
    property bool copied: false
    // The label is dimmed while the report is being built or copied
    property bool collecting: false
    // Reduce motion: no scale, the heap appears at its full height
    property bool still: false
    property int fadeIn: 150
    property int fadeOut: 100
    // The heap and its fade take a little longer to settle than a plain fade
    readonly property int settleMs: 200
    readonly property int pressMs: 100
    readonly property real pressedScale: 0.97

    signal activated

    objectName: "control"
    width: 112
    height: 44
    radius: Theme.cornerRadius
    color: copied ? Theme.withAlpha(Theme.primary, 0.14) : (area.containsMouse ? Theme.surfaceContainerHigh : "transparent")
    border.width: 1
    border.color: copied ? Theme.primary : Theme.outline
    scale: area.pressed && !still ? pressedScale : 1
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: button.activated()
    Keys.onPressed: event => Press.onKey(event, () => button.activated())

    Behavior on color {
        ColorAnimation {
            duration: button.fadeIn
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
        height: 8
        x: 1
        y: parent.height - height - 1
        visible: opacity > 0.01
        opacity: button.copied ? 1 : 0
        transform: Scale {
            origin.y: heap.height
            yScale: button.still || button.copied ? 1 : 0.3
            Behavior on yScale {
                NumberAnimation {
                    duration: button.copied ? button.settleMs : button.fadeOut
                    easing.type: Easing.OutCubic
                }
            }
        }
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity {
            NumberAnimation {
                duration: button.copied ? button.settleMs : button.fadeOut
                easing.type: Easing.OutCubic
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Theme.primary
            PathSvg {
                path: "M0 8V7C" + heap.width * 0.22 + " 7 " + heap.width * 0.3 + " 1 " + heap.width * 0.42 + " 1S" + heap.width * 0.66 + " 6 " + heap.width + " 7V8Z"
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        // 16 px check, 1.5 px round stroke, only once copied
        Shape {
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: opacity > 0.01
            opacity: button.copied ? 1 : 0
            preferredRendererType: Shape.CurveRenderer
            Behavior on opacity {
                NumberAnimation {
                    duration: button.copied ? button.fadeIn : button.fadeOut
                }
            }
            ShapePath {
                strokeWidth: 1.5
                strokeColor: Theme.primary
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M3 8.5L6.5 12L13 4.5"
                }
            }
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: button.label
            font.pixelSize: Theme.fontSizeMedium
            color: button.collecting ? Theme.surfaceVariantText : Theme.surfaceText
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            button.forceActiveFocus();
            button.activated();
        }
    }
}
