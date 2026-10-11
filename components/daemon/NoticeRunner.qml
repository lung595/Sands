import QtQuick
import "Notice.js" as Notice

// Raises "notice due" once per timer, shortly before it ends (SN1). One
// single-shot Timer is armed at the soonest due time and re-armed only when
// the timers change or the setting is read again: no polling, and with no eligible timer
// nothing is armed at all. The rules live in Notice.js; this file only owns the
// notified list and the wake-up. What the user sees is up to the listener.
QtObject {
    id: runner

    // The daemon's timer list (see Lifecycle.js); replaced on every change
    property var timers: []
    // Raw setting, in minutes: absent means the 2 min default, 0 means off
    property var minutes: undefined

    // Emitted once per timer when its notice is due
    signal noticeDue(int id)

    readonly property int notice: Notice.noticeFromSetting(minutes)
    property var _notified: []

    onTimersChanged: rearm()
    onNoticeChanged: rearm()

    // Forgets the ids that may be noticed again, then arms the next wake-up
    function rearm() {
        const now = Date.now();
        _notified = Notice.forget(_notified, timers, now, notice);
        wake.stop();
        const at = Notice.nextDueAt(timers, notice, _notified, now);
        if (at < 0)
            return;
        // Already inside the window: the 1 ms floor raises it at once
        wake.interval = Math.min(2147483647, Math.max(1, at - now));
        wake.start();
    }

    property Timer _wake: Timer {
        id: wake
        repeat: false
        onTriggered: {
            const now = Date.now();
            const due = runner.timers.filter(t => Notice.isDue(t, now, runner.notice, runner._notified));
            due.forEach(t => runner._notified = Notice.markNotified(runner._notified, t.id));
            runner.rearm();
            due.forEach(t => runner.noticeDue(t.id));
        }
    }
}
