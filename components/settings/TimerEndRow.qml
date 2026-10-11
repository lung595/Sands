import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../../AlexBridge.js" as AlexBridge
import "../"

// « When a Sands timer ends »: three choices, one value owned by Alex. The row
// only shows what it is given and asks for a change through `modeRequested`;
// it keeps no copy and writes nothing (Q151). Greyed, with nothing checked,
// when Alex is absent, disabled or unreadable.
Column {
    id: root

    // The mode Alex reported, "" while unread or unreadable
    required property string mode
    // Alex is loaded: false greys the row
    required property bool alexLoaded
    signal modeRequested(string mode)
    // The mark under the greyed row asks for the guide section
    signal guideRequested

    readonly property var view: AlexBridge.rowState(alexLoaded, mode)
    readonly property var choices: AlexBridge.choices()
    // Segments in one line when they fit, stacked when they do not
    // 8 px, the 16 px check and a 4 px gap before the label
    readonly property int slotWidth: Theme.spacingS + 16 + Theme.spacingXS
    readonly property bool stacked: measure.implicitWidth > width

    // Fade length: 150 ms going in, 100 ms going out, 100 ms both ways with Reduce motion
    function fadeMs(growing) {
        return growing && !SettingsData.reduceMotion ? 150 : 100;
    }

    width: parent.width
    spacing: Theme.spacingS

    SettingLabel {
        width: parent.width
        title: "When a Sands timer ends"
        titleColor: root.view.enabled ? Theme.surfaceText : Theme.surfaceVariantText
        description: "Sands always keeps its sound and its bar chip. The Alex island can show the alarm with Stop and Snooze."
    }

    // Each segment at the width of its bold label (check slot, label, right pad)
    // in one hidden line, so selecting one never moves the others and the
    // stacking decision is stable.
    Row {
        id: measure
        visible: false
        spacing: 0

        Repeater {
            id: measureRep
            model: root.choices

            Item {
                required property var modelData
                width: root.slotWidth + bold.implicitWidth + Theme.spacingM
                height: 1

                StyledText {
                    id: bold
                    visible: false
                    text: parent.modelData.label
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Item {
        id: control
        objectName: "control"
        width: segments.width
        height: segments.height

        Grid {
            id: segments
            objectName: "segments"
            width: root.stacked ? root.width : implicitWidth
            columns: root.stacked ? 1 : 3
            // The borders are drawn by the frame and the dividers, not by the segments
            spacing: 0

            Repeater {
                id: segRep
                model: root.choices

                Item {
                    id: seg

                    required property var modelData
                    required property int index
                    readonly property bool checked: root.view.selected === modelData.value
                    // Where the fill stands: full when checked, a veil on hover and press
                    readonly property real shade: !root.view.enabled ? 0 : (checked ? 1 : (mouse.pressed ? 0.16 : (mouse.containsMouse ? 0.12 : 0)))
                    readonly property bool first: index === 0
                    readonly property bool last: index === root.choices.length - 1

                    width: root.stacked ? segments.width : (measureRep.count > index && measureRep.itemAt(index) ? measureRep.itemAt(index).width : 0)
                    // 44 px including the 1 px borders
                    height: Math.max(44, label.implicitHeight + Theme.spacingM * 2)
                    // A greyed segment takes neither the mouse nor the keyboard
                    enabled: root.view.enabled
                    // One tab stop for the group (radio pattern): the checked choice
                    activeFocusOnTab: checked
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: checked
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.modeRequested(modelData.value);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                            // Arrows move and select, wrapping at the ends
                            const step = (event.key === Qt.Key_Left || event.key === Qt.Key_Up) ? -1 : 1;
                            const n = (index + step + root.choices.length) % root.choices.length;
                            root.modeRequested(root.choices[n].value);
                            segRep.itemAt(n).forceActiveFocus();
                            event.accepted = true;
                        }
                    }

                    // Only the outer corners of the control are rounded
                    Rectangle {
                        id: fill
                        anchors.fill: parent
                        color: Theme.primary
                        opacity: seg.shade
                        topLeftRadius: seg.first ? Theme.cornerRadius : 0
                        bottomLeftRadius: (root.stacked ? seg.last : seg.first) ? Theme.cornerRadius : 0
                        topRightRadius: (root.stacked ? seg.first : seg.last) ? Theme.cornerRadius : 0
                        bottomRightRadius: seg.last ? Theme.cornerRadius : 0

                        // Opacity only, so Reduce motion changes nothing but the 150 ms in
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.fadeMs(seg.shade > fill.opacity)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // The line between this segment and the previous one
                    Shape {
                        visible: seg.index > 0
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: Theme.outline
                            strokeWidth: 1
                            strokeStyle: root.view.enabled ? ShapePath.SolidLine : ShapePath.DashLine
                            dashPattern: [5, 4]
                            fillColor: "transparent"
                            startX: root.stacked ? 0 : 0.5
                            startY: root.stacked ? 0.5 : 0
                            PathLine {
                                x: root.stacked ? seg.width : 0.5
                                y: root.stacked ? 0.5 : seg.height
                            }
                        }
                    }

                    StyledText {
                        id: label
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: root.slotWidth
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.modelData.label
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: seg.checked ? Font.DemiBold : Font.Normal
                        wrapMode: Text.WordWrap
                        color: seg.checked ? Theme.primaryText : (root.view.enabled ? Theme.surfaceText : Theme.surfaceVariantText)
                    }

                    // Check of the selected choice, in a slot kept in every segment
                    Shape {
                        x: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        opacity: seg.checked ? 1 : 0
                        // Grows with the fade; opacity only with Reduce motion
                        scale: seg.checked || SettingsData.reduceMotion ? 1 : 0.6
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.fadeMs(seg.checked)
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.fadeMs(seg.checked)
                                easing.type: Easing.OutCubic
                            }
                        }
                        ShapePath {
                            strokeColor: Theme.primaryText
                            strokeWidth: 1.5
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            fillColor: "transparent"
                            PathSvg {
                                path: "M3 8.5l3.5 3.5l6.5-7.5"
                            }
                        }
                    }

                    FocusRing {
                        visible: seg.activeFocus
                        border.color: seg.checked ? Theme.primaryText : Theme.primary
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.modeRequested(seg.modelData.value)
                    }
                }
            }
        }

        // The outline over the fills: dashed when greyed, like the empty seat of the strip
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: Theme.outline
                strokeWidth: 1
                strokeStyle: root.view.enabled ? ShapePath.SolidLine : ShapePath.DashLine
                dashPattern: [5, 4]
                fillColor: "transparent"
                PathRectangle {
                    x: 0.5
                    y: 0.5
                    width: control.width - 1
                    height: control.height - 1
                    radius: Theme.cornerRadius
                }
            }
        }
    }

    StyledText {
        text: "In the bar when it rings"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    // Miniature bar: the Sands chip always rings, Alex's seat follows the choice.
    // The seat is a plain pill until the Alex mascot can be shared (D489, NAK-671).
    Rectangle {
        id: strip
        objectName: "strip"
        readonly property int pad: 4
        readonly property int padX: 8
        width: parent.width
        height: stripRow.implicitHeight + pad * 2
        radius: Theme.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.24)
        Accessible.role: Accessible.Graphic
        Accessible.name: AlexBridge.stripLabel(root.view)

        Row {
            id: stripRow
            x: strip.padX
            y: strip.pad
            spacing: Theme.spacingS

            // The Sands chip always rings: error tint, hourglass, time
            Rectangle {
                width: chipRow.implicitWidth + Theme.spacingS * 2
                height: 28
                radius: 14
                color: Qt.tint(Theme.surfaceContainerHighest, Theme.withAlpha(Theme.error, 0.18))
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "hourglass_top"
                        size: 16
                        color: Theme.error
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "0:00"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.surfaceText
                    }
                }
            }

            // Alex's seat: the form tells who shows the alarm, never the opacity
            Rectangle {
                id: seat
                readonly property string pick: root.view.selected
                onPickChanged: seatFade.restart()
                width: root.view.enabled ? seatRow.implicitWidth + Theme.spacingS * 2 : 32
                height: 28
                radius: 14
                color: root.view.enabled ? Theme.surfaceContainerHighest : "transparent"

                // Greyed: the dashed ring of the control (a Rectangle border cannot dash)
                Shape {
                    visible: !root.view.enabled
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Theme.outline
                        strokeWidth: 1.5
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [5, 4]
                        fillColor: "transparent"
                        PathRectangle {
                            x: 0.75
                            y: 0.75
                            width: seat.width - 1.5
                            height: seat.height - 1.5
                            radius: 14
                        }
                    }
                }

                Row {
                    id: seatRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS
                    visible: root.view.enabled

                    // The new seat fades in once (brief, stops by itself); leaving is instant
                    NumberAnimation on opacity {
                        id: seatFade
                        running: false
                        from: 0
                        to: 1
                        duration: root.fadeMs(true)
                        easing.type: Easing.OutCubic
                    }

                    // Neutral glyph until the mascot can be shared (D489, NAK-671)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.surfaceText
                    }
                    DankIcon {
                        visible: seat.pick !== "sands"
                        anchors.verticalCenter: parent.verticalCenter
                        name: "hourglass_top"
                        size: seat.pick === "alex" ? 16 : 12
                        color: Theme.primary
                    }
                    Rectangle {
                        visible: seat.pick === "alex"
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 16
                        radius: 8
                        color: Theme.primary
                    }
                    Rectangle {
                        visible: seat.pick === "alex"
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 16
                        radius: 8
                        color: "transparent"
                        border.width: 1.5
                        border.color: Theme.outline
                    }
                }
            }
        }
    }

    // « Light on battery » (D419): only when Alex acts at all, never greyed
    Flow {
        visible: root.view.batteryChip
        width: parent.width
        spacing: Theme.spacingS

        Rectangle {
            width: pillRow.implicitWidth + Theme.spacingS * 2
            height: 20
            radius: 10
            color: Theme.withAlpha(Theme.primary, 0.1)
            border.width: 1
            border.color: Theme.outline

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 6

                // Three level bars: the first full, the other two at 30 %
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 2
                            height: 8
                            color: Theme.primary
                            opacity: index === 0 ? 1 : 0.3
                        }
                    }
                }
                StyledText {
                    text: "Light on battery"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
        }

        StyledText {
            width: Math.min(implicitWidth, parent.width)
            text: "One 3 s pose or one island per timer end, nothing between."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }
    }

    // Why the row is greyed, and where to read more (value 10)
    Rectangle {
        visible: !root.view.enabled
        width: parent.width
        height: noteBox.height + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.24)

        Item {
            id: noteBox
            x: Theme.spacingM
            y: Theme.spacingS
            width: parent.width - Theme.spacingM - Theme.spacingXS
            height: Math.max(noteText.implicitHeight, 44)

            Column {
                id: noteText
                anchors.left: parent.left
                anchors.right: link.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: root.alexLoaded ? "Alex did not answer" : "Alex is not installed or is turned off"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    text: root.alexLoaded ? "Sands rings alone. Reopen this page to try again." : "Install or enable Alex to choose. Until then Sands rings alone."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: link
                objectName: "control"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                activeFocusOnTab: true
                Accessible.role: Accessible.Link
                Accessible.name: "Open the guide section about Alex"
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.guideRequested();
                        event.accepted = true;
                    }
                }

                GitHubMark {
                    anchors.centerIn: parent
                    size: 18
                    color: linkMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    Behavior on color {
                        ColorAnimation {
                            duration: root.fadeMs(linkMouse.containsMouse)
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                FocusRing {
                    visible: link.activeFocus
                    border.color: Theme.primary
                }

                MouseArea {
                    id: linkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.guideRequested()
                }
            }
        }
    }
}
