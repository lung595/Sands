import QtQuick
import QtTest
import qs.Common
import "../../components"

// The −1 / +1 / +5 min chips of the panel with real clicks: −1 min stays
// offered until 0:10 (the daemon's floor), so 40 s left can still go down to
// 0:10; it is gone at 0:10 and while the timer rings. Run: tests/qml-page/run.sh
Item {
    id: root
    width: 340
    height: 120

    // Stand-in daemon: records each adjust call
    QtObject {
        id: fakeDaemon
        property var calls: []
        function adjust(id, ms) {
            calls = calls.concat([[id, ms]]);
            return true;
        }
    }

    AdjustChips {
        id: chips
        daemon: fakeDaemon
        timer: ({
                id: 7
            })
        timerState: "running"
        remaining: 40000
    }

    TestCase {
        name: "AdjustChips"
        when: windowShown

        function init() {
            fakeDaemon.calls = [];
            chips.timerState = "running";
            chips.remaining = 40000;
        }

        function test_minusUntilTheFloor() {
            const minus = chips.children[0];
            verify(minus.visible, "40 s left: −1 min is offered");
            mouseClick(minus);
            compare(fakeDaemon.calls, [[7, -60000]], "it asks the daemon for −1 min");
            chips.remaining = 10001;
            verify(minus.visible, "just over 0:10: still offered");
            chips.remaining = 10000;
            verify(!minus.visible, "at 0:10 there is nothing to take off");
        }

        function test_minusHiddenWhileRinging() {
            chips.timerState = "ringing";
            chips.remaining = 600000;
            verify(!chips.children[0].visible, "a ringing timer can't lose time");
            mouseClick(chips.children[1]);
            compare(fakeDaemon.calls, [[7, 60000]], "+1 min still works");
        }
    }
}
