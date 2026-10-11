import QtQuick
import qs.Common
import qs.Widgets

// "Test the alarm": the sound and the visual alert once, through the daemon,
// which owns the alert host. The row only asks; both stop by themselves. The
// button sits under its text, so at any width nothing is drawn over anything else.
Column {
    id: root

    // The key of the row in Sections.js, for the search highlight
    readonly property string settingKey: "testAlarm"
    // False without a daemon and while an alert is already on screen
    property bool ready: true
    signal testRequested

    width: parent.width
    spacing: Theme.spacingS

    SettingLabel {
        width: parent.width
        title: "Test the alarm"
        description: "Plays the sound and the visual alert once, with the choices of this page"
    }

    DankButton {
        text: "Test the alarm"
        iconName: "alarm"
        objectName: "testAlarmButton"
        enabled: root.ready
        onClicked: root.testRequested()
    }
}
