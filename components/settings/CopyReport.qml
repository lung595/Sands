import QtQuick
import qs.Common
import qs.Widgets
import "ReportRow.js" as Words
import "../"
import "../Press.js" as Press

// The "Copy report" row: builds the anonymous report when pressed (nothing runs
// before), copies it with wl-copy --sensitive and says where to paste it. The
// GitHub mark beside the button opens the new-issue page on click only; the
// report is never put in the address and Sands never goes online (D450, D453).
// The daemon owns the work and its states (`daemon.report` and its
// `clipboard`); this row only presses and observes.
Column {
    id: root

    required property var daemon
    // Found by search under this key
    readonly property string settingKey: "report"

    readonly property var service: daemon ? daemon.report : null
    readonly property var copier: service ? service.clipboard : null
    readonly property var view: Words.view(Words.phaseOf(service ? service.busy : false, copier ? copier.result : "idle"), copier ? copier.inHistory === true : false)
    // The mark, for the tests that focus it
    readonly property Item markControl: mark
    readonly property bool copied: view.state === "copied"
    // Reduce motion keeps only the fades
    readonly property bool still: SettingsData.reduceMotion
    // The button and the mark side by side, and the least room the text needs
    // beside them before it takes a line of its own
    readonly property int controlsWidth: 164
    readonly property int textMinWidth: 160
    // Room around the label of the mark: 8 px at its sides, 4 px above and below
    readonly property int labelPadX: 8
    readonly property int labelPadY: 4

    // The only door to the browser; a test swaps it so nothing really opens
    property var openUrl: url => Qt.openUrlExternally(url)
    // The address was opened (click or key press); the test reads this
    signal issuesOpened

    // The service decides: a press during a collection joins it, a press
    // during the copy is one too many
    function press() {
        if (service)
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
        readonly property bool beside: width >= controls.width + spacing + root.textMinWidth

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
                y: controls.height + root.labelPadY
                // Stays inside the column even when the controls sit at its right
                x: Math.min(0, root.width - controlsBox.x - width)
                visible: opacity > 0.01
                opacity: mark.labelled ? 1 : 0
                width: Math.min(labelText.implicitWidth + 2 * root.labelPadX, root.width)
                height: labelText.implicitHeight + 2 * root.labelPadY
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, 0.24)
                Behavior on opacity {
                    NumberAnimation {
                        duration: mark.labelled ? Press.FADE_IN_MS : Press.FADE_OUT_MS
                    }
                }
                StyledText {
                    id: labelText
                    x: root.labelPadX
                    y: root.labelPadY
                    width: parent.width - 2 * root.labelPadX
                    text: "Open an issue on GitHub"
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }

            // The label of the mark sits under the controls, never over the text
            Flow {
                id: controls
                width: Math.min(root.width, root.controlsWidth)
                spacing: Theme.spacingS

                ReportButton {
                    label: root.view.button
                    copied: root.copied
                    collecting: root.view.state === "collecting"
                    still: root.still
                    onActivated: root.press()
                }
                ReportMark {
                    id: mark
                    active: root.view.markActive
                    onActivated: root.openIssues()
                }
            }
        }
    }

    // The guided message when no clipboard tool worked: stays until the next press
    HelpNote {
        daemon: root.daemon
        info: root.view.note
        pinned: true
        maxWidth: root.width
    }

    // Nothing stays "Copied" or "none" after the section is gone
    Component.onDestruction: {
        if (copier)
            copier.reset();
    }
}
