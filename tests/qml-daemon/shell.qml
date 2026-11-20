import QtQuick
import Quickshell

// End-to-end scene of the whole daemon (TimerDaemon.qml and every part it
// loads), run twice by run.sh with the real Quickshell offscreen. It only acts
// and reports: every fact goes to stderr as one "sands-e2e <what> <json>" line,
// and check.js judges them with what the stand-ins on PATH recorded.
// SANDS_E2E_PHASE:
//   ring     empty state; Tea 2 s, Rice 8 s, Bread 1 h, Soup 10 min paused;
//            waits for Tea to ring, lets the alarm play, reads the week, quits
//            (Rice still runs: it ends while no shell is running)
//   restore  the state saved by "ring" (SANDS_E2E_STATE), after Rice's end;
//            reports what came back, starts Egg, stops Tea, then the rest of
//            the ring through the dune's click (its stopRequested), reads the
//            week, quits
ShellRoot {
    id: scene

    readonly property string phase: Quickshell.env("SANDS_E2E_PHASE") || "ring"
    readonly property var saved: JSON.parse(Quickshell.env("SANDS_E2E_STATE") || "{}")

    function say(what, value) {
        console.warn("sands-e2e " + what + " " + JSON.stringify(value));
    }

    // The dune on screen: the scene the alert host loads (the bench stand-in
    // of DuneWindows), found by its surface in the daemon's tree; null at rest
    function dune(item) {
        const node = item || scene.daemon;
        const kids = node ? node.children || [] : [];
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (k && typeof k.stopRequested === "function" && "reason" in k && "screenNames" in k)
                return k;
            const found = scene.dune(k);
            if (found)
                return found;
        }
        return null;
    }

    function snapshot() {
        const d = scene.dune();
        return {
            at: Date.now(),
            timers: scene.daemon.timers,
            ringing: scene.daemon.ringing,
            soundActive: scene.daemon.soundActive,
            alert: scene.daemon.alertShowing,
            dune: d ? {
                name: d.name,
                reason: d.reason
            } : null
        };
    }

    // The week as the views read it: queued behind the journal writes
    function finish() {
        scene.daemon.historyThisWeek(week => {
            scene.say("week", week);
            scene.say("final", scene.snapshot());
            Qt.quit();
        });
    }

    // The daemon under test, created by begin() from the TimerDaemon.qml that
    // run.sh stages next to this file (no static type: alone in tests/ the
    // file still reads for the linter)
    property var daemon: null

    // DMS's plugin settings and state: settings keep their defaults, the
    // state starts from SANDS_E2E_STATE, and every write is reported
    readonly property QtObject service: QtObject {
        signal pluginDataChanged(string pluginId)

        function loadPluginData(id, key, fallback) {
            return fallback;
        }
        function savePluginData(id, key, value) {
            scene.say("data", {
                key: key,
                value: value
            });
        }
        function loadPluginState(id, key, fallback) {
            return key in scene.saved ? scene.saved[key] : fallback;
        }
        function savePluginState(id, key, value) {
            scene.say("save", {
                key: key,
                value: value
            });
        }
        // No other plugin is loaded: nothing may be told to anyone
        function isPluginLoaded(id) {
            return false;
        }
        function setGlobalVar(id, name, value) {
            scene.say("global", {
                id: id,
                name: name
            });
        }
    }

    Connections {
        target: scene.daemon
        function onRingingChanged() {
            scene.say("ringing", scene.snapshot());
            if (scene.phase === "ring" && scene.daemon.ringing)
                afterRing.start();
        }
    }

    // ring: lets the alarm go through its first ramp steps once Tea rings
    Timer {
        id: afterRing
        interval: 2600
        onTriggered: scene.finish()
    }

    // restore: lets the restored alarm and notifications start, then stops
    // Tea alone (Rice keeps ringing), then everything that rings
    Timer {
        id: stopTea
        interval: 1500
        onTriggered: {
            scene.say("egg", scene.daemon.start(300000, "Egg", "duration", 0, true));
            const done = scene.daemon.dismiss(1);
            scene.say("stopTea", Object.assign(scene.snapshot(), {
                done: done
            }));
            stopAll.start();
        }
    }

    Timer {
        id: stopAll
        interval: 1000
        onTriggered: {
            scene.say("stopAll", scene.snapshot());
            // The click on the dune's legend
            const d = scene.dune();
            if (d)
                d.stopRequested();
            afterStop.start();
        }
    }

    Timer {
        id: afterStop
        interval: 1000
        onTriggered: scene.finish()
    }

    // Never hangs: check.js fails on this line
    Timer {
        interval: 15000
        running: true
        onTriggered: {
            scene.say("timeout", scene.snapshot());
            Qt.quit();
        }
    }

    Component.onCompleted: begin()

    // The daemon reads the saved state as it completes, inside createObject
    function begin() {
        const component = Qt.createComponent("TimerDaemon.qml");
        daemon = component.createObject(scene, {
            pluginService: service
        });
        if (!daemon) {
            say("error", component.errorString());
            Qt.quit();
            return;
        }
        if (phase === "ring") {
            say("begin", Date.now());
            scene.daemon.start(2000, "Tea", "duration", 0, true);
            scene.daemon.start(8000, "Rice", "duration", 0, true);
            scene.daemon.start(3600000, "Bread", "duration", 0, true);
            scene.daemon.pause(scene.daemon.start(600000, "Soup", "duration", 0, true));
            say("started", snapshot());
        } else {
            say("restored", snapshot());
            stopTea.start();
        }
    }
}
