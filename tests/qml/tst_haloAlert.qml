import QtQuick
import Quickshell

// needs: components/alert/DuneAlert.qml components/alert/HaloScene.qml components/alert/HaloRim.qml components/alert/HaloMotion.js components/alert/AlertPolicy.js
// stubs: qs
// Offscreen test of the alert host and the Edge halo: the Loader stays inactive
// for "none", for a moment that does not apply and for full screen; the halo
// plays its steps, its Timer stops by itself and the Loader is inactive again
// after dismissal. Run with tests/qml/run.sh; any failure prints FAIL.
ShellRoot {
    id: root

    property bool failed: false
    property int stage: 0

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    DuneAlert {
        id: host
        layerShell: true
        windowed: false
        timerName: "Pasta"
        soundState: ({ outputMuted: true })
    }

    function inactive(kind, when, sound, full, over, what) {
        host.kind = kind;
        host.when = when;
        host.soundState = sound;
        host.fullscreen = full;
        host.showOverFullscreen = over;
        host.ring();
        check(!host.showing, what);
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (root.stage === 0) {
                root.inactive("none", "always", {}, false, false, "none stays inactive");
                root.inactive("halo", "muted", { volume: 0.5 }, false, false, "audible with moment muted stays inactive");
                root.inactive("halo", "always", {}, true, false, "full screen stays inactive");
                root.inactive("dune", "always", {}, false, false, "dune without a scene stays inactive");
                host.layerShell = false;
                root.inactive("halo", "always", {}, false, false, "no layer shell stays inactive");
                root.check(!host.haloAvailable, "halo unavailable without layer shell");
                host.layerShell = true;
                host.kind = "halo";
                host.when = "muted";
                host.soundState = { outputMuted: true };
                host.fullscreen = false;
                host.ring();
                root.check(host.showing, "halo shows when muted");
                root.stage = 1;
            } else if (root.stage === 1) {
                root.check(host.scene.running || host.scene.level > 0, "halo plays");
                root.stage = 11;
            } else if (root.stage === 11 && !host.scene.running) {
                // the sequence ended by itself: the rim is posed and the Timer is off
                root.check(host.scene.level === 1, "rim posed at the end");
                host.dismiss();
                root.stage = 2;
            } else if (root.stage === 2 && !host.showing) {
                root.check(true, "");
                host.test();
                root.check(host.showing, "test plays the choice");
                root.stage = 3;
            } else if (root.stage === 3 && !host.showing) {
                // the test dismissed itself; the halo Timer must be gone with it
                root.check(host.scene === null, "scene destroyed after the test");
                console.warn(root.failed ? "FAIL" : "qml PASS");
                Qt.exit(root.failed ? 1 : 0);
            }
        }
    }
}
