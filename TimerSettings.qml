import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "L10n.js" as L

PluginSettings {
    id: root

    // UI language (plugin setting, reactive)
    readonly property string lang: SettingsData.pluginSettings["smartTimer"]?.language || "auto"

    pluginId: "smartTimer"

    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null

    // Sounds installed on the machine (sound themes + ~/.local/share/sounds),
    // without the audio channel test sounds.
    property var soundOptions: [
        {
            label: L.tr(root.lang, "Réveil (par défaut)"),
            value: ""
        },
        {
            label: L.tr(root.lang, "Fichier personnel…"),
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
                        label: L.tr(root.lang, "Fichier personnel…"),
                        value: "custom"
                    }
                ]);
            }
        }
    }

    SelectionSetting {
        settingKey: "language"
        label: L.tr(root.lang, "Langue")
        options: [
            {
                label: L.tr(root.lang, "Automatique (langue du système)"),
                value: "auto"
            },
            {
                label: "Français",
                value: "fr"
            },
            {
                label: "English",
                value: "en"
            }
        ]
        defaultValue: "auto"
    }

    // ------------------------------------------------------------------
    // Sound
    // ------------------------------------------------------------------

    StyledText {
        width: parent.width
        text: L.tr(root.lang, "Son de fin")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    SelectionSetting {
        id: soundSetting
        settingKey: "sound"
        label: L.tr(root.lang, "Son")
        description: L.tr(root.lang, "Joué en boucle quand un minuteur arrive à zéro")
        options: root.soundOptions
        defaultValue: ""
    }

    StringSetting {
        id: customSetting
        visible: soundSetting.value === "custom"
        settingKey: "customSound"
        label: L.tr(root.lang, "Fichier son")
        description: L.tr(root.lang, "Chemin complet d'un fichier .oga, .ogg, .wav, .mp3 ou .flac")
        placeholder: L.tr(root.lang, "~/Musique/sonnerie.mp3")
        defaultValue: ""
    }

    DankButton {
        text: L.tr(root.lang, "Écouter")
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
        label: L.tr(root.lang, "Volume")
        defaultValue: 80
        minimum: 0
        maximum: 100
        unit: "%"
        leftIcon: "volume_down"
        rightIcon: "volume_up"
    }

    SliderSetting {
        settingKey: "ringDuration"
        label: L.tr(root.lang, "Durée de la sonnerie")
        description: L.tr(root.lang, "Le son s'arrête seul après ce délai ; la pastille continue de clignoter jusqu'à ce qu'on l'arrête")
        defaultValue: 60
        minimum: 10
        maximum: 300
        unit: "s"
    }

    ToggleSetting {
        settingKey: "notify"
        label: L.tr(root.lang, "Notification à la fin")
        description: L.tr(root.lang, "Avec les boutons « Arrêter » et « +5 min » : utile en plein écran, quand la barre est cachée")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "rampUp"
        label: L.tr(root.lang, "Sonnerie progressive")
        description: L.tr(root.lang, "Commence doucement puis monte jusqu'au volume choisi")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "tick"
        label: L.tr(root.lang, "Tic-tac final")
        description: L.tr(root.lang, "Un tic discret à chacune des 10 dernières secondes")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "respectDnd"
        label: L.tr(root.lang, "Respecter « Ne pas déranger »")
        description: L.tr(root.lang, "En « Ne pas déranger », aucun son : la pastille pulse quand même")
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
        text: L.tr(root.lang, "Lanceur")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        id: noTriggerSetting
        settingKey: "noTrigger"
        label: L.tr(root.lang, "Détection automatique")
        description: L.tr(root.lang, "Reconnaît « timer 20 min », « 25m pâtes » ou « à 18h » sans préfixe. Désactivé : il faut taper le préfixe ci-dessous.")
        defaultValue: true
    }

    StringSetting {
        visible: !noTriggerSetting.value
        settingKey: "trigger"
        label: L.tr(root.lang, "Préfixe")
        description: L.tr(root.lang, "Exemple avec « timer » : « timer 20 min »")
        placeholder: "timer"
        defaultValue: "timer"
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        text: L.tr(root.lang, "Exemples : timer 20 min · minuteur 1h30 · 25m pâtes · 1:30 · une demi-heure · trois quarts d'heure · à 18h30 · at 6pm · timer 14h30
En ligne de commande : dms ipc call smartTimer start \"12 min pâtes\" (aussi : toggle, stop, add 5, list, clear)")
    }
}
