import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// The "Alerts & sounds" section: what rings, how loud, for how long.
Column {
    id: root

    // [{label, value}] sounds to pick from, and the daemon that plays a preview
    required property var soundOptions
    required property var daemon

    width: parent.width
    spacing: Theme.spacingM

    ChoiceRow {
        id: soundSetting
        settingKey: "sound"
        label: "Sound"
        description: "Loops when a timer reaches zero"
        options: root.soundOptions
        defaultValue: "default"
    }

    StringSetting {
        id: customSetting
        visible: soundSetting.value === "custom"
        settingKey: "customSound"
        label: "Sound file"
        description: "Full path to an .oga, .ogg, .wav, .mp3 or .flac file"
        placeholder: "~/Music/alarm.mp3"
        defaultValue: ""
    }

    DankButton {
        text: "Preview"
        iconName: "play_arrow"
        enabled: root.daemon !== null
        onClicked: {
            if (!root.daemon)
                return;
            root.daemon.previewSound(root.daemon.soundPath(soundSetting.value, customSetting.value));
        }
    }

    SliderSetting {
        settingKey: "volume"
        label: "Volume"
        defaultValue: 80
        minimum: 0
        maximum: 100
        unit: "%"
        leftIcon: "volume_down"
        rightIcon: "volume_up"
    }

    SwitchRow {
        settingKey: "rampUp"
        label: "Gentle alarm"
        description: "Starts softly, then rises to the chosen volume"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "ringDuration"
        label: "Alarm duration"
        description: "The sound stops by itself after this delay; the pill keeps pulsing until you stop it"
        defaultValue: 60
        minimum: 10
        maximum: 300
        unit: "s"
    }

    SwitchRow {
        settingKey: "tick"
        label: "Final countdown ticks"
        description: "A soft tick on each of the last 10 seconds"
        level: "light"
        cost: "Plays a sound on each of the last 10 seconds"
        defaultValue: false
    }

    SwitchRow {
        settingKey: "notify"
        label: "Notification when done"
        description: "With “Stop” and “+5 min” buttons: handy in fullscreen, when the bar is hidden"
        defaultValue: true
    }

    SwitchRow {
        settingKey: "respectDnd"
        label: "Respect Do Not Disturb"
        description: "In Do Not Disturb, no sound: the pill still pulses"
        defaultValue: true
    }
}
