import QtQuick
import qs.Services
import "AlertPolicy.js" as Policy
import "DuneStyles.js" as Styles
import "../daemon/Sound.js" as Sound

// Wires the visual alert to the timer engine: feeds the host with the saved
// choices and the state of the sound, and rings it when the engine rings.
// The sound, the DMS notification and the IPC are not touched here.
Item {
    id: root

    // The timer engine (TimerDaemon): ringing state, settings, the actions
    required property var engine
    // The alarm sound part, which owns the Do not disturb rule
    required property var sound

    // Several timers ending together share one dune named after the last one
    readonly property var lastRinging: Policy.lastRinging(engine.timers)
    // Setting keys are placeholders until the settings row story saves them
    readonly property string when: engine.setting("alertWhen", Policy.DEFAULT_WHEN)
    property int _seed: 1

    // What the alarm would sound like now, for the "only when muted" moment
    readonly property var _soundState: ({
            choice: engine.setting("sound", ""),
            volume: Sound.volumeOf(engine.setting("volume", 80)),
            outputMuted: sound.muted() || AudioService.sink?.audio?.muted === true,
            hasOutput: AudioService.sink !== null && AudioService.sink !== undefined
        })

    Connections {
        target: root.engine
        function onRingingChanged() {
            if (root.engine.ringing) {
                root._seed = (Date.now() % 65535) + 1;
                alert.ring();
            } else {
                alert.dismiss();
            }
        }
    }

    DuneAlert {
        id: alert
        kind: root.engine.setting("alertKind", Policy.DEFAULT_KIND)
        when: root.when
        soundState: root._soundState
        showOverFullscreen: root.engine.setting("duneOverFullscreen", false)
        timerName: root.lastRinging ? root.engine.displayLabel(root.lastRinging) : ""
        duneScene: DuneWindows {
            style: root.engine.setting("duneStyle", Styles.DEFAULT)
            name: alert.timerName
            reason: Policy.legendReason(alert.kind, root.when, root._soundState)
            overFullscreen: alert.showOverFullscreen
            seed: root._seed
            onStopRequested: root.engine.dismissRinging()
        }
    }
}
