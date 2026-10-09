import QtQuick
import qs.Common

// The other timers, under a thin rule. Each line shows its own state.
Column {
    id: root

    required property var daemon
    // Comma-separated ids: only changes when the list changes, not on every
    // clock tick (otherwise the Repeater would recreate its rows 4 times
    // per second).
    required property string idsKey

    signal picked(int id)

    spacing: 2

    Rectangle {
        width: parent.width - Theme.spacingM * 2
        anchors.horizontalCenter: parent.horizontalCenter
        height: 1
        color: Theme.withAlpha(Theme.outline, 0.18)
    }

    Item {
        width: 1
        height: Theme.spacingXS
    }

    Repeater {
        model: root.idsKey === "" ? [] : root.idsKey.split(",").map(Number)

        delegate: OtherTimerRow {
            required property var modelData
            width: root.width
            daemon: root.daemon
            timerId: modelData
            onPicked: id => root.picked(id)
        }
    }
}
