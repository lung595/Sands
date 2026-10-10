.pragma library

// Pure rules of the "notice before the end" (SN1), shared by the daemon and
// its tests: no QML, no clock of its own (the time is always passed in), no
// timer object, no side effects. The caller owns the list of notified ids
// and gives back the time it wants to be woken at.
//
// A timer is the one described in Lifecycle.js.
//
// Rule for the caller: a timer that is restarted (Lifecycle.restart) must be
// taken out of the notified list, otherwise dueAt keeps answering -1 and the
// restarted run never gets its notice. The caller also runs Lifecycle.expire
// before asking nextDueAt, so an overdue timer does not re-arm a 0 ms wake-up.

// Most ids remembered, so the list cannot grow without bound
var MAX_NOTIFIED = 64;
// Longest accepted notice (one hour); anything above is treated as silent
var MAX_NOTICE_MS = 3600000;

// The notice length in ms, or 0 (silent) when the setting is missing,
// negative, not a number or out of range
function noticeMs(minutes) {
    // Only numbers and strings: Number(true) or Number([3]) would switch it on
    const n = typeof minutes === "number" || typeof minutes === "string" ? Math.floor(Number(minutes)) : NaN;
    return n > 0 && n * 60000 <= MAX_NOTICE_MS ? n * 60000 : 0;
}

// Whether a timer may ever get a notice: it must be longer than the notice,
// otherwise the notice would come at once, which is just noise
function eligible(t, notice) {
    return notice > 0 && t.total > notice;
}

// When the notice of a running timer is due, or -1 if there is none to wait
// for (silent, too short, not running, already given). The result moves with
// `endAt`, so a pause then a resume is followed without any extra state.
function dueAt(t, notice, notified) {
    if (t.state !== "running" || !eligible(t, notice) || notified.indexOf(t.id) >= 0)
        return -1;
    return t.endAt - notice;
}

// True once the notice of a running timer is due and the time has not run out
// (a timer that already ends gets its alarm, not a notice)
function isDue(t, now, notice, notified) {
    const at = dueAt(t, notice, notified);
    return at >= 0 && now >= at && now < t.endAt;
}

// The soonest due time over the timers, or -1: the one wake-up the caller
// needs (nothing to wake for means nothing runs)
function nextDueAt(timers, notice, notified) {
    let best = -1;
    for (const t of timers) {
        const at = dueAt(t, notice, notified);
        if (at >= 0 && (best < 0 || at < best))
            best = at;
    }
    return best;
}

// The notified list with `id` added once (new array, capped to the newest)
function markNotified(notified, id) {
    if (notified.indexOf(id) >= 0)
        return notified.slice();
    return notified.concat([id]).slice(-MAX_NOTIFIED);
}

// The notified list without the ids of timers that no longer exist
function prune(notified, timers) {
    return notified.filter(id => timers.some(t => t.id === id));
}
