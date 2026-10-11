import QtQuick
import qs.Common
import "Journal.js" as Journal

// "Threads": one poured thread per name, its length the time. Each thread
// pours once when the view opens (a brief scale from the left), then rests.
Column {
    id: root

    // [{ name, ms, folded }], longest first, already folded to seven
    required property var shown
    required property bool reducedMotion

    readonly property var fractions: Journal.threadFractions(shown)

    spacing: Theme.spacingM

    Repeater {
        model: root.shown
        delegate: Column {
            id: block

            required property var modelData
            required property int index

            width: root.width
            spacing: Theme.spacingXS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                ElidedName {
                    width: parent.width - timeText.width - parent.spacing
                    text: block.modelData.name
                }

                StyledTime {
                    id: timeText
                    text: Journal.duration(block.modelData.ms)
                }
            }

            Rectangle {
                id: track
                width: parent.width
                height: 8
                radius: 4
                color: Theme.surfaceContainerHighest

                Rectangle {
                    height: parent.height
                    radius: 4
                    color: Theme.primary
                    width: Math.max(Journal.THREAD_MIN_PX, root.fractions[block.index] * track.width)
                    transform: Scale {
                        id: pour
                        origin.x: 0
                        xScale: root.reducedMotion ? 1 : 0
                    }
                }
            }

            SequentialAnimation {
                running: !root.reducedMotion
                PauseAnimation {
                    duration: 30 * block.index
                }
                NumberAnimation {
                    target: pour
                    property: "xScale"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
