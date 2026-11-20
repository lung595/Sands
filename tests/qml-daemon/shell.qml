import QtQuick
import Quickshell
import qs.Common
import qs.Services

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
//   mute     empty state; Mint 2 s muted, Bread 1 h renamed with emoji,
//            Soup 10 min; Bread stopped and brought back, Soup stopped for
//            good; Mint rings without sound, its dune shown although the
//            alert is set to "only when muted"; then pause all / resume all,
//            Soup's undo once its 5 s are over, quits
// The ring run starts from the settings of an older Sands (the end mode and
// the end actions, gone in 1.7.0): the daemon must drop them, say once that
// the end actions are gone, and end Tea as always. The restore run gives Rice
// the end action an older Sands could have saved: Rice must ring as any other.
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
            removed: scene.daemon.removed.map(r => r.timer.id),
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
            scene.say("toasts", ToastService.shown);
            scene.say("final", scene.snapshot());
            Qt.quit();
        });
    }

    // The daemon under test, created by begin() from the TimerDaemon.qml that
    // run.sh stages next to this file (no static type: alone in tests/ the
    // file still reads for the linter)
    property var daemon: null

    // DMS's plugin settings and state: settings keep their defaults (but the
    // alert moment of "mute"), the state starts from SANDS_E2E_STATE, and
    // every write is reported
    readonly property QtObject service: QtObject {
        signal pluginDataChanged(string pluginId)

        // mute: the dune only for a ring that cannot be heard
        function loadPluginData(id, key, fallback) {
            return key === "alertWhen" && scene.phase === "mute" ? "muted" : fallback;
        }
        function savePluginData(id, key, value) {
            scene.say("data", {
                key: key,
                value: value
            });
        }
        function loadPluginState(id, key, fallback) {
            const value = key in scene.saved ? scene.saved[key] : fallback;
            if (key === "timers" && scene.phase === "restore" && Array.isArray(value))
                return value.map(t => t.label === "Rice" ? Object.assign({
                        actionId: "poweroff"
                    }, t) : t);
            return value;
        }
        function savePluginState(id, key, value) {
            scene.say("save", {
                key: key,
                value: value
            });
        }
        // Every plugin counts as loaded (any other plugin): still nothing may be told
        // to anyone when a timer ends
        function isPluginLoaded(id) {
            return true;
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
            if (scene.phase === "mute" && scene.daemon.ringing)
                afterMute.start();
        }
        // The launcher's cue: once per change of the list, never per second
        function onTimersChanged() {
            scene.say("changed", Date.now());
        }
    }

    // mute: lets the silent ring go on, then pause all and resume all
    Timer {
        id: afterMute
        interval: 1500
        onTriggered: {
            const paused = scene.daemon.pauseAll();
            const pausedAgain = scene.daemon.pauseAll();
            scene.say("pauseAll", Object.assign(scene.snapshot(), {
                paused: paused,
                again: pausedAgain
            }));
            scene.say("resumeAll", Object.assign({
                resumed: scene.daemon.resumeAll()
            }, scene.snapshot()));
            lateUndo.start();
        }
    }

    // mute: Soup's undo after its 5 s
    Timer {
        id: lateUndo
        interval: 2500
        onTriggered: {
            scene.say("lateUndo", Object.assign({
                done: scene.daemon.undoRemove(3)
            }, scene.snapshot()));
            scene.finish();
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
        // An older Sands saved its end mode and end actions; another plugin's
        // keys are not Sands'
        SettingsData.pluginSettings = phase === "ring" ? {
            smartTimer: {
                endMode: "auto",
                timerEndMode: "sands",
                personalActions: [{
                        name: "Lights",
                        program: "lights",
                        args: ["off"]
                    }],
                actionWords: {
                    poweroff: ["off", "film"]
                },
                hourglassStyle: "classic"
            },
            other: {
                endMode: "keep"
            }
        } : {
            smartTimer: {
                hourglassStyle: "classic"
            }
        };
        const component = Qt.createComponent("TimerDaemon.qml");
        daemon = component.createObject(scene, {
            pluginService: service
        });
        if (!daemon) {
            say("error", component.errorString());
            Qt.quit();
            return;
        }
        say("settings", {
            settings: SettingsData.pluginSettings,
            saves: SettingsData.pluginSettingsSaves
        });
        if (phase === "ring") {
            say("begin", Date.now());
            scene.daemon.start(2000, "Tea", "duration", 0, true);
            scene.daemon.start(8000, "Rice", "duration", 0, true);
            scene.daemon.start(3600000, "Bread", "duration", 0, true);
            scene.daemon.pause(scene.daemon.start(600000, "Soup", "duration", 0, true));
            say("started", snapshot());
        } else if (phase === "mute") {
            say("begin", Date.now());
            const mint = scene.daemon.start(2000, "Mint", "duration", 0, true);
            const muted = scene.daemon.toggleMute(mint);
            const bread = scene.daemon.start(3600000, "Bread", "duration", 0, true);
            const soup = scene.daemon.start(600000, "Soup", "duration", 0, true);
            say("started", Object.assign(snapshot(), {
                ids: [mint, bread, soup],
                muted: muted,
                rename: scene.daemon.rename(bread, "\uD83C\uDF5E Pain  frais \uD83D\uDC4D\uD83C\uDFFD"),
                renameEmpty: scene.daemon.rename(soup, "\uD83C\uDF72\uFE0F")
            }));
            const stopped = scene.daemon.remove(bread);
            say("stopBread", Object.assign(snapshot(), {
                done: stopped
            }));
            const back = scene.daemon.undoRemove(bread);
            say("undoBread", Object.assign(snapshot(), {
                done: back,
                again: scene.daemon.undoRemove(bread)
            }));
            say("stopSoup", Object.assign({
                done: scene.daemon.remove(soup)
            }, snapshot()));
        } else {
            say("restored", snapshot());
            stopTea.start();
        }
    }
}
