import QtQuick
import Quickshell
import qs.Common
import "components/alert"

// needs: components/alert/DuneAlert.qml components/alert/HaloScene.qml components/alert/HaloRim.qml components/alert/HaloMotion.js components/alert/AlertPolicy.js components/daemon/PlainText.js
// stubs: qs
// layout: tree
// Offscreen test of the alert host and the Edge halo: the Loader stays inactive
// for "none", for a moment that does not apply and for full screen; the halo
// plays its steps, its Timer stops by itself and the Loader is inactive again
// after dismissal; test() and a real alert never disturb each other. Run with
// tests/qml/run.sh; any failure prints FAIL.
ShellRoot {
    id: root

    property bool failed: false
    property int stage: 0
    property int ticks: 0

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    // Stand-in for the dune: finishes as soon as it is dismissed
    Component {
        id: duneStub
        Item {
            signal finished
            function dismiss() {
                finished();
            }
        }
    }

    // A dune that cannot exit by itself (no dismiss, no finished)
    Component {
        id: mutedStub
        Item {}
    }

    DuneAlert {
        id: host
        layerShell: true
        windowed: false
        timerName: "Pasta"
        soundState: ({
                outputMuted: true
            })
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

    function setup(kind, when, sound, full, over) {
        host.kind = kind;
        host.when = when;
        host.soundState = sound;
        host.fullscreen = full;
        host.showOverFullscreen = over;
    }

    // Each step runs once the previous one is over; it returns true when done,
    // false to be polled again on the next tick.
    property var steps: [function () {
            inactive("none", "always", {}, false, false, "none stays inactive");
            inactive("halo", "muted", {
                volume: 0.5
            }, false, false, "audible with moment muted stays inactive");
            inactive("halo", "always", {}, true, false, "full screen stays inactive");
            inactive("dune", "always", {}, false, false, "dune without a scene stays inactive");
            host.layerShell = false;
            inactive("halo", "always", {}, false, false, "no layer shell stays inactive");
            check(!host.haloAvailable, "halo unavailable without layer shell");
            host.layerShell = true;
            setup("halo", "muted", {
                outputMuted: true
            }, false, false);
            host.ring();
            check(host.showing, "halo shows when muted");
            return true;
        }, function () {
            check(host.scene.running || host.scene.level > 0, "halo plays");
            return true;
        }, function () {
            if (host.scene.running)
                return false;
            // the sequence ended by itself: the rim is posed and the Timer is off
            check(host.scene.level === 1, "rim posed at the end");
            host.dismiss();
            return true;
        }, function () {
            if (host.showing)
                return false;
            check(host.scene === null, "scene destroyed after dismissal");
            // always + audible shows; full screen shows when allowed
            setup("halo", "always", {
                volume: 0.8
            }, false, false);
            host.ring();
            check(host.showing, "always shows with an audible sound");
            host.dismiss();
            return true;
        }, function () {
            if (host.showing)
                return false;
            setup("halo", "always", {}, true, true);
            host.ring();
            check(host.showing, "full screen shows when allowed");
            host.dismiss();
            return true;
        }, function () {
            if (host.showing)
                return false;
            // Reduce motion: the posed rim at once, no Timer, immediate dismissal
            SettingsData.reduceMotion = true;
            setup("halo", "always", {}, false, false);
            host.ring();
            check(host.showing, "halo shows with Reduce motion");
            check(host.scene.level === 1 && !host.scene.running, "Reduce motion: posed at once, Timer never runs");
            host.dismiss();
            check(!host.showing && host.scene === null, "Reduce motion: dismissal is immediate");
            SettingsData.reduceMotion = false;
            return true;
        }, function () {
            // an em dash in a timer name never reaches the screen
            host.timerName = "Tea — green";
            setup("halo", "always", {}, false, false);
            host.ring();
            check(host.showing && host.scene.legend.indexOf("—") < 0 && host.scene.legend.indexOf("Tea - green is done") === 0, "legend without em dash");
            host.dismiss();
            host.timerName = "Pasta";
            return true;
        }, function () {
            if (host.showing)
                return false;
            // the dune scene is loaded, then destroyed
            host.duneScene = duneStub;
            setup("dune", "always", {}, false, false);
            host.ring();
            check(host.showing, "dune shows when a scene is wired");
            host.dismiss();
            check(!host.showing && host.scene === null, "dune scene destroyed after dismissal");
            // a scene without dismiss() is still removed
            host.duneScene = mutedStub;
            host.ring();
            check(host.showing, "scene without finished shows");
            host.dismiss();
            check(!host.showing, "scene without dismiss is removed");
            host.duneScene = null;
            return true;
        }, function () {
            // test() keeps the real name and replays the choice with "Pasta"
            host.timerName = "Real";
            setup("halo", "muted", {
                volume: 0.9
            }, false, false);
            host.test();
            check(host.showing, "test plays the choice");
            check(host.timerName === "Real", "test leaves timerName alone");
            check(host.scene.legend.indexOf("Pasta is done") === 0, "test legend uses the fake name");
            return true;
        }, function () {
            // a real alert replaces the playing test and is not cut by its end
            setup("halo", "always", {}, false, false);
            host.ring();
            check(host.showing && host.scene.legend.indexOf("Real is done") === 0, "real alert replaces the test");
            return true;
        }, function () {
            // wait past the test end (2.5 s): the real alert must still be up
            if (root.ticks++ < 60)
                return false;
            check(host.showing, "stale test end does not dismiss a real alert");
            host.dismiss();
            return true;
        }, function () {
            if (host.showing)
                return false;
            host.test();
            return true;
        }, function () {
            if (host.showing)
                return false;
            // the test dismissed itself; the halo Timer is gone with it
            check(host.scene === null, "scene destroyed after the test");
            console.warn(root.failed ? "FAIL" : "qml PASS");
            Qt.exit(root.failed ? 1 : 0);
            return true;
        }]

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (root.stage < root.steps.length && root.steps[root.stage]())
                root.stage++;
        }
    }
}
