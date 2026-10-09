import QtQuick

// Pill motion clock (ms). A plain Timer instead of looping
// Animators: those would make every DMS window redraw at the
// display rate for as long as the alarm rings (possibly for
// hours if nobody is there); this only redraws the bar. 60 Hz
// for the quick beat and bell, 30 Hz for the slow breathing.
//
// An alarm nobody answers does not animate forever: like the
// sound, the pill stops moving after the alarm duration and
// stays lit (still red) until it is dismissed.
Item {
    id: clock

    property var daemon: null
    // Timer state of the pill; a change re-arms the ringing limit.
    property string timerState: "idle"
    property bool running: false
    property bool fast: false
    readonly property bool ringing: timerState === "ringing"

    property real fxMs: 0
    property bool settled: false

    onTimerStateChanged: settled = false

    Timer {
        interval: clock.fast ? 16 : 33
        repeat: true
        running: clock.running
        property real start: 0
        onRunningChanged: {
            start = Date.now();
            clock.fxMs = 0;
        }
        onTriggered: {
            clock.fxMs = Date.now() - start;
            if (clock.ringing && clock.fxMs > (clock.daemon ? clock.daemon.ringLimitMs() : 60000))
                clock.settled = true;
        }
    }
}
