import QtQuick
import Quickshell

// needs: components/PillClock.qml
// Offscreen test of the pill ringing limit: once the alarm has settled, a new
// alarm sound (a second timer finishing while the pill still rings) re-arms it.
// Run with tests/qml/run.sh; any failure prints FAIL.
ShellRoot {
    id: root

    property bool failed: false

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    QtObject {
        id: fake
        property bool soundActive: true
        function ringLimitMs() {
            return 60000;
        }
    }

    PillClock {
        id: clock
        daemon: fake
        timerState: "ringing"
    }

    Component.onCompleted: {
        // The first alarm rang past the limit, its sound has stopped
        clock.settled = true;
        fake.soundActive = false;
        check(clock.settled, "settled stays while the sound stops");
        // A second timer finishes: its sound starts
        fake.soundActive = true;
        check(!clock.settled, "a new alarm sound re-arms the ringing limit");
        // The final-countdown beat keeps the clock running into the ring,
        // which starts 10 s into the beat: its limit counts from the ring
        clock.timerState = "running";
        clock.running = true;
        clock.fxMs = 10000;
        clock.timerState = "ringing";
        check(clock.fxMs === 0, "the ringing limit counts from the ring, not from the beat");
        console.warn(failed ? "FAIL" : "qml PASS");
        Qt.exit(failed ? 1 : 0);
    }
}
