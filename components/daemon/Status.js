.pragma library
.import "../../Timers.js" as Timers

// The JSON `dms ipc call smartTimer status` answers, for scripts. Pure: the
// time is passed in, nothing is polled or kept (value 6). It carries only
// what the user typed (the labels) and numbers; the lists are capped so a
// reply can never grow without bound (value 11).

var MAX_TIMERS = 100;
var MAX_LABEL = 200;

// `sortedTimers` in display order, `now` in ms. `phase` is the timer state
// ("running", "paused" or "ringing"); `remaining` and `total` are whole
// seconds, `remaining` never negative.
function build(sortedTimers, now) {
    const timers = sortedTimers.slice(0, MAX_TIMERS).map(t => ({
        id: t.id,
        label: Timers.displayLabel(t).slice(0, MAX_LABEL),
        phase: t.state,
        remaining: Math.max(0, Math.ceil(Timers.remainingOf(t, now) / 1000)),
        total: Math.round((t.total || 0) / 1000)
    }));
    return JSON.stringify({
        count: sortedTimers.length,
        ringing: sortedTimers.some(t => t.state === "ringing"),
        timers: timers
    });
}
