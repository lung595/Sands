import QtQuick
import qs.Services
import "AlertPolicy.js" as Policy
import "DuneStyles.js" as Styles
import "DuneMotion.js" as Motion
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
    // The saved choices, written by the rows of "Alerts & sounds"
    readonly property string kind: _read("alertKind", Policy.DEFAULT_KIND)
    readonly property string when: _read("alertWhen", Policy.DEFAULT_WHEN)
    readonly property string style: _read("duneStyle", Styles.DEFAULT)
    readonly property bool overFullscreen: _read("duneOverFullscreen", false) === true
    property int _seed: 1

    // Read by the settings page: greys the Edge halo card, holds the test button
    readonly property bool haloAvailable: alert.haloAvailable
    readonly property bool showing: alert.showing

    // Bumped when a setting of this plugin is saved, so the choices above are
    // read again without a restart. No timer, no polling.
    property int _rev: 0

    function _read(key, fallback) {
        _rev;
        return engine.setting(key, fallback);
    }

    // "Test the alarm" of the settings page: the saved choice once, whatever
    // the moment, named "Pasta". Does nothing while an alert is on screen.
    function test() {
        if (alert.showing)
            return;
        _seed = (Date.now() % 65535) + 1;
        alert.test();
    }

    Connections {
        target: root.engine.pluginService ?? null
        ignoreUnknownSignals: true
        function onPluginDataChanged(pluginId) {
            if (pluginId === root.engine.pluginId)
                root._rev++;
        }
    }

    // What the alarm would sound like now, for the "only when muted" moment
    readonly property var _soundState: ({
            choice: _read("sound", ""),
            volume: Sound.volumeOf(_read("volume", 80)),
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
        kind: root.kind
        when: root.when
        soundState: root._soundState
        showOverFullscreen: root.overFullscreen
        timerName: root.lastRinging ? root.engine.displayLabel(root.lastRinging) : ""
        // The dune needs its whole rise before a test dismisses it
        testMs: Policy.kindOf(root.kind) === "dune" ? Math.round(Motion.DURATION[Styles.drawnOf(root.style)] * 1000) + 1500 : 2500
        duneScene: DuneWindows {
            style: root.style
            // A test has no timer: same made-up name and reason as the halo test
            name: alert.testing ? "Pasta" : alert.timerName
            reason: alert.testing ? "Click to stop" : Policy.legendReason(alert.kind, root.when, root._soundState)
            overFullscreen: alert.showOverFullscreen
            seed: root._seed
            onStopRequested: {
                if (alert.testing)
                    alert.dismiss();
                else
                    root.engine.dismissRinging();
            }
        }
    }
}
