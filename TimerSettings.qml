import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "smartTimer"

    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null

    // Sounds installed on the machine (sound themes + ~/.local/share/sounds),
    // without the audio channel test sounds.
    property var soundOptions: [
        {
            label: "Alarm clock (default)",
            value: ""
        },
        {
            label: "Custom file…",
            value: "custom"
        }
    ]

    function prettify(path) {
        const parts = path.split("/");
        const file = parts[parts.length - 1].replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ");
        const themeIdx = parts.indexOf("sounds");
        const theme = themeIdx >= 0 && parts.length > themeIdx + 2 ? parts[themeIdx + 1] : "";
        const name = file.charAt(0).toUpperCase() + file.slice(1);
        return theme ? name + " · " + theme : name;
    }

    Process {
        id: soundScan
        running: true
        command: ["sh", "-c", "find /usr/share/sounds /usr/local/share/sounds \"$HOME/.local/share/sounds\" -type f \\( -iname '*.oga' -o -iname '*.ogg' -o -iname '*.wav' -o -iname '*.mp3' -o -iname '*.flac' \\) 2>/dev/null | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const skip = /\/alsa\/|speech-dispatcher|audio-channel-|audio-test-signal|\/sf2\//;
                const found = text.split("\n").filter(p => p && !skip.test(p) && p !== "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga").map(p => ({
                            label: root.prettify(p),
                            value: p
                        }));
                root.soundOptions = [root.soundOptions[0]].concat(found, [
                    {
                        label: "Custom file…",
                        value: "custom"
                    }
                ]);
            }
        }
    }

    SelectionSetting {
        settingKey: "hourglassStyle"
        label: "Hourglass"
        description: "Only the hourglass changes: sand, freeze and flip stay the same"
        options: [
            {
                label: "Classic",
                value: "classic"
            },
            {
                // A nod to Steven Universe
                label: "Glass of Time",
                value: "glassOfTime"
            }
        ]
        defaultValue: "classic"
    }

    // ------------------------------------------------------------------
    // Sound
    // ------------------------------------------------------------------

    StyledText {
        width: parent.width
        text: "Alarm sound"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    SelectionSetting {
        id: soundSetting
        settingKey: "sound"
        label: "Sound"
        description: "Loops when a timer reaches zero"
        options: root.soundOptions
        defaultValue: ""
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
            const choice = soundSetting.value;
            let path = "";
            if (choice === "custom")
                path = (customSetting.value || "").trim().replace(/^~(?=\/)/, Quickshell.env("HOME"));
            else
                path = choice;
            root.daemon.previewSound(path || root.daemon.defaultSound);
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

    SliderSetting {
        settingKey: "ringDuration"
        label: "Alarm duration"
        description: "The sound stops by itself after this delay; the pill keeps pulsing until you stop it"
        defaultValue: 60
        minimum: 10
        maximum: 300
        unit: "s"
    }

    ToggleSetting {
        settingKey: "notify"
        label: "Notification when done"
        description: "With “Stop” and “+5 min” buttons: handy in fullscreen, when the bar is hidden"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "rampUp"
        label: "Gentle alarm"
        description: "Starts softly, then rises to the chosen volume"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "tick"
        label: "Final countdown ticks"
        description: "A soft tick on each of the last 10 seconds"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "respectDnd"
        label: "Respect Do Not Disturb"
        description: "In Do Not Disturb, no sound: the pill still pulses"
        defaultValue: true
    }

    // ------------------------------------------------------------------
    // Launcher
    // ------------------------------------------------------------------

    Item {
        width: parent.width
        height: Theme.spacingM
    }

    StyledText {
        width: parent.width
        text: "Launcher"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        id: noTriggerSetting
        settingKey: "noTrigger"
        label: "Automatic detection"
        description: "Understands “timer 20 min”, “25m pasta” or “at 6pm” without a prefix. Off: type the prefix below first."
        defaultValue: true
    }

    StringSetting {
        visible: !noTriggerSetting.value
        settingKey: "trigger"
        label: "Prefix"
        description: "Example with “timer”: “timer 20 min”"
        placeholder: "timer"
        defaultValue: "timer"
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        text: "Examples: timer 20 min · 1h30 · 25m pasta · 1:30 · half an hour · at 6:30pm · timer 14h30. French works too: une demi-heure · 12 min pâtes · à 18h30\nCommand line: dms ipc call smartTimer start \"12 min pasta\" (also: toggle, stop, add 5, list, clear, panel)"
    }
}
