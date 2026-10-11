import QtQuick
import Quickshell

// needs: components/daemon/NoticeRunner.qml components/daemon/Notice.js
// Offscreen test of NoticeRunner with a 1 minute notice and timers that are
// 1 s away from it. Run with tests/qml/run.sh; any failure prints FAIL and exits 1.
ShellRoot {
    id: root

    property int step: 0
    property bool failed: false
    property var seen: []

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    function timer(id, total, state, endIn) {
        return {
            id: id,
            total: total,
            state: state,
            endAt: Date.now() + endIn,
            remaining: endIn
        };
    }

    NoticeRunner {
        id: runner
        minutes: 1
        onNoticeDue: id => root.seen = root.seen.concat([id])
    }

    // Each step runs 1.5 s after the previous one, long enough for the 1 s wake-up
    Timer {
        id: clock
        interval: 1500
        repeat: true
        onTriggered: root.next()
    }

    function next() {
        step++;
        if (step === 1) {
            check(root.seen.length === 0, "nothing before any timer");
            // 1: due in 1 s. 2: shorter than the notice. 3: paused. 4: the same as 1 but notice off later
            runner.timers = [timer(1, 61000, "running", 61000), timer(2, 30000, "running", 30000), timer(3, 61000, "paused", 61000)];
        } else if (step === 2) {
            check(root.seen.length === 1 && root.seen[0] === 1, "only timer 1 is noticed: " + JSON.stringify(root.seen));
            // A new list with the same timer must not raise it again
            runner.timers = runner.timers.slice();
        } else if (step === 3) {
            check(root.seen.length === 1, "raised once per timer");
            // Restart: the end moves out of the window, so it is noticed again
            runner.timers = [timer(1, 61000, "running", 61000)];
        } else if (step === 4) {
            check(root.seen.length === 2, "a restarted timer is noticed again: " + JSON.stringify(root.seen));
            // Resumed inside the window: no second notice
            runner.timers = [timer(1, 61000, "running", 30000)];
        } else if (step === 5) {
            check(root.seen.length === 2, "a resume inside the window stays silent");
            // Added time pushes the end out of the window, then it comes due again
            runner.timers = [timer(1, 91000, "running", 61000)];
        } else if (step === 6) {
            check(root.seen.length === 3, "added time is noticed again: " + JSON.stringify(root.seen));
            // Setting off: a due timer is never raised
            runner.minutes = 0;
            runner.timers = [timer(4, 61000, "running", 61000)];
        } else if (step === 7) {
            check(root.seen.length === 3, "off raises nothing");
            // Absent setting means the 2 min default: a 61 s timer is too short for it
            runner.minutes = undefined;
            runner.timers = [timer(5, 61000, "running", 61000)];
            check(runner.notice === 120000, "default is 2 min");
        } else if (step === 8) {
            check(root.seen.length === 3, "a timer shorter than the default is never noticed");
            // Snooze: a ringing timer is not noticed, once running again it is
            runner.minutes = 1;
            runner.timers = [timer(6, 61000, "ringing", 0)];
            check(!runner._wake.running, "a ringing timer arms nothing");
        } else if (step === 9) {
            check(root.seen.length === 3, "a ringing timer is not noticed");
            runner.timers = [timer(6, 61000, "running", 61000)];
        } else if (step === 10) {
            check(root.seen.length === 4 && root.seen[3] === 6, "a snoozed timer is noticed: " + JSON.stringify(root.seen));
            // Pause right after the start: the wake-up is cancelled
            runner.timers = [timer(7, 61000, "running", 61000)];
            runner.timers = [timer(7, 61000, "paused", 61000)];
            check(!runner._wake.running, "a paused timer arms nothing");
        } else if (step === 11) {
            check(root.seen.length === 4, "a paused timer is not noticed");
            runner.timers = [timer(7, 61000, "running", 61000)];
        } else if (step === 12) {
            check(root.seen.length === 5 && root.seen[4] === 7, "a resumed timer is noticed: " + JSON.stringify(root.seen));
            // Overdue (wake after suspend): left to the daemon, no 1 ms re-arm loop
            runner.timers = [timer(8, 61000, "running", -5000)];
            check(!runner._wake.running, "an overdue timer arms nothing");
        } else if (step === 13) {
            check(root.seen.length === 5, "an overdue timer is not noticed");
            runner.timers = [];
            check(!runner._wake.running, "nothing armed without a timer");
            clock.stop();
            console.warn(failed ? "FAIL" : "qml PASS");
            Qt.exit(failed ? 1 : 0);
        }
    }

    Component.onCompleted: clock.start()
}
