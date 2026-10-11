import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "ReportRow.js" as Words
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
    readonly property var view: Words.view(Words.phaseOf(service ? service.busy : false, copier ? copier.result : "idle"))
    // The mark, for the tests that focus it
    readonly property Item markControl: mark
    readonly property bool copied: view.state === "copied"
    // One-shot fades: 150 ms in, 100 ms out; Reduce motion keeps only opacity
    readonly property int fadeIn: 150
    readonly property int fadeOut: 100
    readonly property bool still: SettingsData.reduceMotion

    // The only door to the browser; a test swaps it so nothing really opens
    property var openUrl: url => Qt.openUrlExternally(url)
    // The address was opened (click or key press); the test reads this
    signal issuesOpened

    function press() {
        if (view.state === "collecting")
            return;
        copier.result = "idle";
        service.request("button");
    }

    function openIssues() {
        openUrl(Words.GITHUB_URL);
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
                text: Words.TITLE
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

        // The label of the mark hangs off this box without taking room in the row
        Item {
            id: controlsBox
            width: controls.width
            height: controls.height
            z: 1

            Rectangle {
                id: markLabel
                y: controls.height + 4
                // Stays inside the column even when the controls sit at its right
                x: Math.min(0, root.width - controlsBox.x - width)
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
                            duration: root.fadeIn
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
                        transform: Scale {
                            origin.y: heap.height
                            yScale: root.still || root.copied ? 1 : 0.3
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: root.copied ? 200 : root.fadeOut
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        preferredRendererType: Shape.CurveRenderer
                        Behavior on opacity {
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

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        // 16 px check, 1.5 px round stroke, only once copied
                        Shape {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: opacity > 0.01
                            opacity: root.copied ? 1 : 0
                            preferredRendererType: Shape.CurveRenderer
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.copied ? root.fadeIn : root.fadeOut
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
                            text: root.view.button
                            font.pixelSize: Theme.fontSizeMedium
                            color: root.view.state === "collecting" ? Theme.surfaceVariantText : Theme.surfaceText
                        }
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
    }

    // The guided message when no clipboard tool worked: stays until the next press
    HelpNote {
        id: message
        daemon: root.daemon
        info: root.view.note
        fill: true
        sticky: true
        maxWidth: root.width
    }

    // Nothing stays "Copied" or "none" after the section is gone
    Component.onDestruction: {
        if (copier)
            copier.result = "idle";
    }

    // Back to rest alone; runs only while "Copied" is shown
    Timer {
        running: root.copied
        interval: 4000
        onTriggered: root.copier.result = "idle"
    }
}
