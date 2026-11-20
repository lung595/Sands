.pragma library

// Pure state transitions of the timer list, shared by TimerDaemon.qml and
// its tests: no QML, no clock of its own (the time is always passed in), no
// side effects. The `pause`, `resume`, `restart` and `adjust` functions
// change the copy of the timer they are given, never a stored one.
//
// A timer is { id, label, kind: "duration" | "at", total, endAt, remaining,
// state: "running" | "paused" | "ringing", finishedAt, hue, muted }.
// `muted` (absent = false) rings that timer without sound: dune and
// notification only.

// A timer already ringing when the shell stopped is announced again at
// startup only if it finished less than this long ago
var STALE_MS = 60000;
// The optional tick sounds during this last stretch of a running timer
var TICK_WINDOW_MS = 10050;
// Taking time off never leaves less than this: "pasta -5" with 3 min left
// gives 0:10, never an end by mistake
var FLOOR_MS = 10000;
// How long a stopped timer can be brought back (the "Stopped · Undo" card)
var UNDO_MS = 5000;

// Display order: ringing first, then the soonest to finish, then paused ones
function sortTimers(timers) {
    const rank = t => t.state === "ringing" ? 0 : (t.state === "running" ? 1 : 2);
    const key = t => t.state === "running" ? t.endAt : (t.state === "paused" ? t.remaining : t.finishedAt);
    return timers.slice().sort((a, b) => rank(a) - rank(b) || key(a) - key(b));
}

// A new running timer. `at` is the wanted end for kind "at".
function make(id, ms, label, kind, at, t0, maxLabel) {
    const endAt = kind === "at" && at ? at : t0 + ms;
    return {
        id: id,
        label: String(label || "").substring(0, maxLabel).trim(),
        kind: kind === "at" ? "at" : "duration",
        total: endAt - t0,
        endAt: endAt,
        remaining: endAt - t0,
        state: "running",
        finishedAt: 0,
        hue: 0
    };
}

function pause(t, now) {
    if (t.state !== "running")
        return;
    t.remaining = Math.max(0, t.endAt - now);
    t.state = "paused";
}

function resume(t, now) {
    if (t.state !== "paused")
        return;
    t.endAt = now + t.remaining;
    t.state = "running";
}

// Adds (or removes) `deltaMs`. A ringing timer restarts for that duration
// instead ("+1 min" = repeat). Taking time off stops at FLOOR_MS. Returns
// false when nothing changed (already at the floor, or over maxMs).
function adjust(t, now, deltaMs, maxMs) {
    if (t.state === "ringing") {
        if (deltaMs <= 0 || deltaMs > maxMs)
            return false;
        t.state = "running";
        t.endAt = now + deltaMs;
        t.total = deltaMs;
        t.finishedAt = 0;
        t.kind = "duration";
        return true;
    }
    const rem = t.state === "running" ? t.endAt - now : t.remaining;
    const next = deltaMs < 0 ? Math.max(rem + deltaMs, FLOOR_MS) : rem + deltaMs;
    if (deltaMs < 0 ? next >= rem : (deltaMs === 0 || next < 1000 || next > maxMs))
        return false;
    if (t.state === "running")
        t.endAt += next - rem;
    else
        t.remaining = next;
    t.total = Math.max(t.total + Math.max(0, deltaMs), next);
    return true;
}

// Every running timer paused (or every paused one resumed) in one new list,
// for a single save: { list, changed: how many }
function pauseAll(timers, now) {
    return _each(timers, t => t.state === "running", t => pause(t, now));
}

function resumeAll(timers, now) {
    return _each(timers, t => t.state === "paused", t => resume(t, now));
}

function _each(timers, wanted, fn) {
    let changed = 0;
    const list = timers.map(t => {
        if (!wanted(t))
            return t;
        const copy = Object.assign({}, t);
        fn(copy);
        changed++;
        return copy;
    });
    return { list: list, changed: changed };
}

// Stops timer `id`: { list, kept } where `kept` is `removed` (the timers
// that can still be brought back, [{ timer, at }]) with this one added, unless
// it was ringing (stopping a ring is the answer to it, nothing to undo).
// `list` is null when there is no such timer.
function takeOut(timers, removed, id, now) {
    const t = timers.find(x => x.id === id);
    const kept = pruneRemoved(removed, now).filter(r => r.timer.id !== id);
    if (!t)
        return { list: null, kept: kept };
    return {
        list: timers.filter(x => x.id !== id),
        kept: t.state === "ringing" ? kept : kept.concat([{ timer: t, at: now }])
    };
}

// What can still be brought back at `now`
function pruneRemoved(removed, now) {
    return (removed || []).filter(r => now - r.at < UNDO_MS);
}

// Brings timer `id` back as it was when stopped (a running one kept its end
// time, so it may ring at once): { list, kept }, `list` null when it is too
// late, unknown, already back or there is no room (`maxTimers`). `id` -1 is
// the last one stopped.
function putBack(timers, removed, id, now, maxTimers) {
    const kept = pruneRemoved(removed, now);
    const r = id === -1 ? kept[kept.length - 1] : kept.find(x => x.timer.id === id);
    if (!r || timers.some(t => t.id === r.timer.id) || timers.length >= maxTimers)
        return { list: null, kept: kept };
    return {
        list: timers.concat([r.timer]),
        kept: kept.filter(x => x !== r)
    };
}

// True when a ringing timer that is not muted is in the list: the alarm
// sound has a reason to play
function audible(timers) {
    return timers.some(t => t.state === "ringing" && !t.muted);
}

// Starts the timer again for its full duration (an alarm "at" a time
// becomes a plain duration)
function restart(t, now) {
    const dur = t.kind === "at" ? Math.max(t.total, 1000) : t.total;
    t.kind = "duration";
    t.total = dur;
    t.endAt = now + dur;
    t.remaining = dur;
    t.state = "running";
    t.finishedAt = 0;
}

// The list at `now`: running timers whose end passed are ringing. Always a
// new array; untouched timers are the same objects. `fired` holds the ids of
// the timers that rang just now, the only ones the journal and the
// notification have to handle.
function expire(timers, now) {
    const fired = [];
    const list = timers.map(t => {
        if (t.state !== "running" || t.endAt > now)
            return t;
        fired.push(t.id);
        return Object.assign({}, t, {
            state: "ringing",
            finishedAt: t.endAt,
            remaining: 0
        });
    });
    return { list: list, fired: fired };
}

// "Ring a timer that finished during sleep if it is less than N min old":
// the choices of the slider, 0 = never
var WAKE_CHOICES = [0, 1, 5, 15, 60];
var WAKE_DEFAULT = 5;
// A tick this much later than planned means the machine slept (or the clock
// jumped): the timers that ended meanwhile go through `settle`
var WAKE_GAP_MS = 5000;

// The saved slider value brought to the nearest choice (default when unreadable)
function wakeMinutes(v) {
    const n = Number(v);
    if (v === null || v === undefined || v === "" || !isFinite(n))
        return WAKE_DEFAULT;
    return WAKE_CHOICES.reduce((best, c) => Math.abs(c - n) < Math.abs(best - n) ? c : best, WAKE_CHOICES[0]);
}

// One rule for the timers that ended while nobody watched (shell off, machine
// asleep): `expire`, then each one that ended `thresholdMs` ago or more is
// stale: it stays in the list as ringing (Done), but gets only a quiet note
// and its journal line, no sound, no dune. { list, fired: [{ id, stale, timer }] }, `timer` being the
// ringing copy. Infinity as threshold: nothing is stale (a normal tick).
function settle(list, now, thresholdMs) {
    const r = expire(list, now);
    const fired = r.list.filter(t => r.fired.indexOf(t.id) >= 0).map(t => ({
        id: t.id,
        stale: now - t.finishedAt >= thresholdMs,
        timer: t
    }));
    return {
        list: r.list,
        fired: fired
    };
}

// True when a running timer is in its last seconds (the optional tick)
function inFinalSeconds(timers, now) {
    return timers.some(t => t.state === "running" && t.endAt - now > 0 && t.endAt - now <= TICK_WINDOW_MS);
}

// Milliseconds until the displayed second of any timer changes, so the
// engine wakes about once per second; -1 when nothing needs a wake-up
// (everything paused or no timer).
function nextDelay(timers, now) {
    let next = -1;
    for (let i = 0; i < timers.length; i++) {
        const t = timers[i];
        let d = -1;
        if (t.state === "running") {
            const r = t.endAt - now;
            d = r <= 0 ? 0 : (r % 1000 || 1000);
        } else if (t.state === "ringing") {
            d = 1000 - ((now - t.finishedAt) % 1000);
        }
        if (d >= 0 && (next < 0 || d < next))
            next = d;
    }
    return next;
}

// What was saved, brought up to `now` through `settle`:
// { list, nextId, fired, again }. `fired` as settle gives it (the timers that
// ended while the shell was off); `again` holds the ids of the timers that
// were already ringing when the shell stopped, less than STALE_MS ago (a
// restart during a ring): they ring on, without a new journal line.
function restore(saved, savedNextId, now, thresholdMs) {
    let nextId = savedNextId;
    const clean = (Array.isArray(saved) ? saved : []).filter(t => t && t.id !== undefined).map(t => {
        nextId = Math.max(nextId, t.id + 1);
        return Object.assign({}, t);
    });
    const r = settle(clean, now, thresholdMs === undefined ? WAKE_DEFAULT * 60000 : thresholdMs);
    return {
        list: r.list,
        nextId: nextId,
        fired: r.fired,
        again: clean.filter(t => t.state === "ringing" && now - t.finishedAt < STALE_MS).map(t => t.id)
    };
}
