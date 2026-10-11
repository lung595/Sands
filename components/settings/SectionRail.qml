import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// The left rail: 160 x 40 entries (logo + name) with 8 px at each side. The open
// section is marked by one heap of sand that slides to its entry, then settles
// (scaleY). Both are one-shot transitions: nothing runs at rest. Reduce motion:
// the heap is simply at its place and fades in for 150 ms.
Item {
    id: root

    // [{id, label}] in rail order
    required property var sections
    property string current: ""
    signal picked(string id)

    readonly property int entryHeight: 40
    readonly property int entryStep: 44
    readonly property int currentIndex: {
        for (let i = 0; i < sections.length; i++) {
            if (sections[i].id === current)
                return i;
        }
        return -1;
    }

    implicitHeight: column.height

    // Keyboard: Up and Down open the neighbour section and move the focus to it
    function step(delta) {
        const next = currentIndex + delta;
        if (next < 0 || next >= sections.length)
            return;
        picked(sections[next].id);
        repeater.itemAt(next).forceActiveFocus();
    }

    Column {
        id: column
        x: 8
        width: 160
        spacing: root.entryStep - root.entryHeight

        Repeater {
            id: repeater
            model: root.sections

            delegate: Rectangle {
                id: entry

                required property var modelData
                readonly property bool open: modelData.id === root.current

                width: 160
                height: root.entryHeight
                radius: Theme.cornerRadius
                color: open ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (hover.hovered ? Theme.surfaceContainerHigh : "transparent")
                objectName: "control"
                // Tab reaches the rail once (the open entry), arrows move inside it
                activeFocusOnTab: open
                Keys.onUpPressed: root.step(-1)
                Keys.onDownPressed: root.step(1)
                Keys.onReturnPressed: root.picked(modelData.id)
                Keys.onSpacePressed: root.picked(modelData.id)

                Behavior on color {
                    enabled: !SettingsData.reduceMotion
                    ColorAnimation {
                        duration: hover.hovered ? 150 : 80
                    }
                }

                HoverHandler {
                    id: hover
                }
                TapHandler {
                    onTapped: root.picked(entry.modelData.id)
                }

                SectionLogo {
                    id: logo
                    sectionId: entry.modelData.id
                    size: 20
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: entry.open ? Theme.primary : (hover.hovered ? Theme.surfaceText : Theme.surfaceVariantText)
                }

                StyledText {
                    anchors.left: logo.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.label
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: entry.open ? Font.DemiBold : Font.Normal
                    color: entry.open ? Theme.surfaceText : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                // Focus ring, drawn inside the entry so the column never clips it
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    visible: entry.activeFocus
                }
            }
        }
    }

    // The heap: one shape for the whole rail, travelling by y only
    Item {
        id: heap
        x: 8
        y: Math.max(0, root.currentIndex) * root.entryStep
        width: 160
        height: root.entryHeight
        opacity: root.currentIndex >= 0 ? 1 : 0
        transform: Scale {
            id: settle
            origin.y: heap.height
            yScale: 1
        }

        Behavior on y {
            enabled: !SettingsData.reduceMotion
            NumberAnimation {
                duration: 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.primary
                strokeColor: "transparent"
                PathSvg {
                    path: "M4 40V38.5C10 38.5 13 33 20 33S32 37.5 56 38.5L156 39.5V40Z"
                }
            }
        }

        // One-shot on every change of section; nothing runs afterwards
        Connections {
            function onCurrentChanged() {
                if (SettingsData.reduceMotion)
                    fadeIn.restart();
                else
                    settleIn.restart();
            }
            target: root
        }
        SequentialAnimation {
            id: settleIn
            PropertyAction {
                target: settle
                property: "yScale"
                value: 0.3
            }
            PauseAnimation {
                duration: 200
            }
            NumberAnimation {
                target: settle
                property: "yScale"
                to: 1
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
            }
        }
        SequentialAnimation {
            id: fadeIn
            PropertyAction {
                target: heap
                property: "opacity"
                value: 0
            }
            NumberAnimation {
                target: heap
                property: "opacity"
                to: 1
                duration: 150
            }
        }
    }
}
