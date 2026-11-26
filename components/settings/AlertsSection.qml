import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../../Guide.js" as Guide
import "../alert/AlertPolicy.js" as AlertPolicy
import "../alert/DuneStyles.js" as DuneStyles
import "../daemon/Lifecycle.js" as Lifecycle
import "../"
import "../Press.js" as Press

// The "Alerts & sounds" section: what is drawn and what rings when a timer
// ends, how loud, for how long. The visual alert itself lives in the daemon
// (RingAlert): this section only saves the choices and asks for a test.
Column {
    id: root

    // [{label, value}] sounds to pick from, and the daemon that plays a preview
    required property var soundOptions
    required property var daemon

    // The screens plugged in now ({ name, model }); follows a screen plugged or unplugged
    property var screens: Quickshell.screens ?? []

    width: parent.width
    spacing: Theme.spacingM

    // Without a daemon nothing says otherwise: the card stays usable
    readonly property bool haloAvailable: !root.daemon || root.daemon.haloAvailable !== false

    CardChoice {
        id: kindSetting
        settingKey: "alertKind"
        label: "Visual alert"
        description: "Drawn on screen when a timer ends"
        defaultValue: "dune"
        options: [
            {
                "label": "Rising dune",
                "value": "dune",
                "help": "Sand rises from the bottom edge"
            },
            {
                "label": "Edge halo",
                "value": "halo",
                "help": "A rim of light around the screen",
                "enabled": root.haloAvailable,
                "reason": "Needs the Wayland layer shell"
            },
            {
                "label": "None",
                "value": "none",
                "help": "Nothing is drawn"
            }
        ]
    }

    // Why the halo card is greyed, with the mark that opens the guide on click
    Row {
        width: parent.width
        spacing: Theme.spacingS
        visible: !root.haloAvailable

        StyledText {
            width: parent.width - mark.width - parent.spacing
            text: "Edge halo needs the Wayland layer shell, which this session does not offer."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        Item {
            id: mark
            anchors.verticalCenter: parent.verticalCenter
            width: Press.TARGET
            height: Press.TARGET
            activeFocusOnTab: true
            Accessible.role: Accessible.Link
            Accessible.name: "Open the guide"
            Accessible.onPressAction: mark.open()
            function open() {
                Qt.openUrlExternally(Guide.URL + "#" + Guide.VISUAL_ANCHOR);
            }
            Keys.onPressed: event => Press.onKey(event, () => mark.open())

            FocusRing {
                border.color: Theme.primary
                visible: mark.activeFocus
            }
            GitHubMark {
                anchors.centerIn: parent
                size: Press.MARK_SIZE
                color: area.containsMouse ? Theme.primary : Theme.surfaceVariantText
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mark.open()
            }
        }
    }

    // Every screen, the one in use when the timer ends, or one screen by name.
    // A saved screen that is unplugged stays listed; the alert then goes to all.
    ChoiceRow {
        settingKey: "alertScreen"
        visible: kindSetting.value !== "none"
        label: "Show on"
        description: "Which screen the alert is drawn on. A screen that is unplugged gives all screens"
        options: AlertPolicy.screenChoices(root.screens, value)
        defaultValue: "all"
    }

    // Three styles, one card each. A style whose scene is not written yet is
    // greyed and cannot be picked; a saved one is shown as what is really drawn.
    CardChoice {
        settingKey: "duneStyle"
        visible: kindSetting.value === "dune"
        label: "Rising dune style"
        description: "How the sand comes up"
        defaultValue: "grains"
        shown: DuneStyles.drawnOf(value)
        options: DuneStyles.choices()
    }

    SwitchRow {
        settingKey: "duneOverFullscreen"
        visible: kindSetting.value === "dune"
        label: "Show above full screen"
        description: "The dune also rises over a full-screen window, such as a video or a game"
        defaultValue: false
    }

    ChoiceRow {
        settingKey: "alertWhen"
        visible: kindSetting.value !== "none"
        label: "Show the visual alert"
        description: "With the sound, or only in its place"
        options: [
            {
                "label": "Every time",
                "value": "always"
            },
            {
                "label": "When sound is off",
                "value": "muted"
            }
        ]
        defaultValue: "always"
    }

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
        onClicked: root.daemon.previewSound(root.daemon.soundPath(soundSetting.value, customSetting.value))
    }

    TestAlarmRow {
        ready: root.daemon !== null && root.daemon.alertShowing !== true
        onTestRequested: {
            root.daemon.previewSound(root.daemon.soundPath(soundSetting.value, customSetting.value));
            root.daemon.testAlert();
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

    // Choices 0 (never), 1, 5, 15, 60: a list of the exact choices, so what
    // is shown is always what is used
    ChoiceRow {
        settingKey: "wakeRingMinutes"
        label: "Ring after sleep"
        description: "A timer that finished during sleep rings if it is less than this old"
        defaultValue: "5"
        options: Lifecycle.WAKE_CHOICES.map(m => ({
                    label: m === 0 ? "Never" : m + " min",
                    value: String(m)
                }))
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
