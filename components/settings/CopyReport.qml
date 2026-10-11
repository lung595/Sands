import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "ReportRow.js" as Row
import "../"

// The "Copy report" row: builds the anonymous report when pressed (nothing runs
// before), copies it with wl-copy --sensitive and says where to paste it. The
// GitHub mark beside the button opens the new-issue page on click only; the
// report is never put in the address and Sands never goes online (D450, D453).
// The daemon owns the work (`daemon.report`, `daemon.reportClipboard`); this
// row only presses and observes.
Column {
    id: root

    required property var daemon
    // Found by search under this key
    readonly property string settingKey: "report"

    readonly property var service: daemon ? daemon.report : null
    readonly property var copier: daemon ? daemon.reportClipboard : null
    readonly property var view: Row.view(Row.phaseOf(service ? service.busy : false, copier ? copier.result : "idle"))
    readonly property bool copied: view.state === "copied"
    // One-shot fades: 150 ms in, 100 ms out; Reduce motion keeps only opacity
    readonly property int fadeIn: 150
    readonly property int fadeOut: 100
    readonly property bool still: SettingsData.reduceMotion

    // The address was opened (click or key press); the test reads this
    signal issuesOpened

    function press() {
        if (view.state === "collecting")
            return;
        copier.result = "idle";
        service.request("button");
    }

    function openIssues() {
        Qt.openUrlExternally(Row.GITHUB_URL);
        issuesOpened();
    }

    width: parent ? parent.width : 0
    spacing: Theme.spacingS

    Flow {
        id: flow
        width: parent.width
        spacing: Theme.spacingM
        // The text takes the line when the controls do not fit beside 160 px of it
        readonly property bool beside: width >= controls.width + spacing + 160

        Column {
            width: flow.beside ? flow.width - controls.width - flow.spacing : flow.width
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                text: Row.TITLE
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                wrapMode: Text.WordWrap
            }
            StyledText {
                width: parent.width
                text: root.view.help
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
        }

        Flow {
            id: controls
            width: Math.min(root.width, 164)
            spacing: Theme.spacingS
            // The label of the mark sits under the controls, never over the text
            property bool markLabel: mark.activeFocus || markArea.containsMouse

            Rectangle {
                id: button
                objectName: "control"
                width: 112
                height: 44
                radius: Theme.cornerRadius
                color: root.copied ? Theme.withAlpha(Theme.primary, 0.14) : (buttonArea.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                border.width: 1
                border.color: root.copied ? Theme.primary : Theme.outline
                scale: buttonArea.pressed && !root.still ? 0.97 : 1
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: root.view.button
                Accessible.onPressAction: root.press()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.press();
                        event.accepted = true;
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: root.copied ? root.fadeIn : root.fadeOut
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
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
                    opacity: root.copied ? 1 : 0
                    transformOrigin: Item.Bottom
                    scale: root.still || root.copied ? 1 : 0.3
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.copied ? 200 : root.fadeOut
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: root.copied ? 200 : root.fadeOut
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

                StyledText {
                    anchors.centerIn: parent
                    text: root.view.button
                    font.pixelSize: Theme.fontSizeMedium
                    color: root.view.state === "collecting" ? Theme.surfaceVariantText : Theme.surfaceText
                }

                MouseArea {
                    id: buttonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        button.forceActiveFocus();
                        root.press();
                    }
                }
            }

            Item {
                id: mark
                objectName: "control"
                width: 44
                height: 44
                activeFocusOnTab: true
                Accessible.role: Accessible.Link
                Accessible.name: "Open a new issue for Sands on GitHub"
                Accessible.onPressAction: root.openIssues()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.openIssues();
                        event.accepted = true;
                    }
                }

                FocusRing {
                    border.color: Theme.primary
                    visible: mark.activeFocus
                }
                GitHubMark {
                    anchors.centerIn: parent
                    size: 18
                    color: root.view.markActive || controls.markLabel ? Theme.primary : Theme.surfaceVariantText
                    Behavior on color {
                        ColorAnimation {
                            duration: controls.markLabel || root.view.markActive ? root.fadeIn : root.fadeOut
                        }
                    }
                }
                MouseArea {
                    id: markArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openIssues()
                }
            }
        }
    }

    // Under the controls, 4 px below; wraps inside the column
    Rectangle {
        id: markLabel
        visible: opacity > 0.01
        opacity: controls.markLabel ? 1 : 0
        width: Math.min(labelText.implicitWidth + 16, root.width)
        height: labelText.implicitHeight + 8
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.24)
        Behavior on opacity {
            NumberAnimation {
                duration: controls.markLabel ? root.fadeIn : root.fadeOut
            }
        }
        StyledText {
            id: labelText
            x: 8
            y: 4
            width: parent.width - 16
            text: "Open an issue on GitHub"
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }

    // The guided message when no clipboard tool worked: stays until the next press
    Rectangle {
        id: message
        visible: root.view.note !== null
        width: parent.width
        height: visible ? noteRow.implicitHeight + 16 : 0
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.24)
        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.view.note ? root.view.note.title : ""
        Accessible.description: root.view.note ? root.view.note.hint : ""

        Row {
            id: noteRow
            x: 12
            y: 8
            spacing: Theme.spacingM
            Column {
                width: message.width - 24 - 28 - Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                StyledText {
                    width: parent.width
                    text: root.view.note ? root.view.note.title : ""
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }
                StyledText {
                    width: parent.width
                    text: root.view.note ? root.view.note.hint : ""
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
            Item {
                objectName: "control"
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                Accessible.role: Accessible.Link
                Accessible.name: "Open the guide: Report a problem"
                GitHubMark {
                    anchors.centerIn: parent
                    size: 18
                    color: noteLink.containsMouse ? Theme.primary : Theme.surfaceVariantText
                }
                MouseArea {
                    id: noteLink
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(root.daemon.guideUrl + "#" + root.view.note.anchor)
                }
            }
        }
    }

    // Back to rest alone; runs only while "Copied" is shown
    Timer {
        running: root.copied
        interval: 4000
        onTriggered: root.copier.result = "idle"
    }
}
