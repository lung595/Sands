.pragma library

// Pure state transitions of the timer list, shared by TimerDaemon.qml and
// its tests: no QML, no clock of its own (the time is always passed in), no
// side effects. The `pause`, `resume`, `restart` and `adjust` functions
// change the copy of the timer they are given, never a stored one.
//
// A timer is { id, label, kind: "duration" | "at", total, endAt, remaining,
// state: "running" | "paused" | "ringing", finishedAt, hue }.

// A ringing alarm that finished more than this long ago (shell off) is not
// announced again at startup
var STALE_MS = 60000;
// The optional tick sounds during this last stretch of a running timer
var TICK_WINDOW_MS = 10050;

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
// instead ("+1 min" = repeat). Returns false when nothing changed (out of
// the 1 s .. maxMs range).
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
    const next = rem + deltaMs;
    if (next < 1000 || next > maxMs)
        return false;
    if (t.state === "running")
        t.endAt += deltaMs;
    else
        t.remaining = next;
    t.total = Math.max(t.total + Math.max(0, deltaMs), next);
    return true;
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
// new array; untouched timers are the same objects. `fired` tells if any rang.
function expire(timers, now) {
    let fired = false;
    const list = timers.map(t => {
        if (t.state !== "running" || t.endAt > now)
            return t;
        fired = true;
        return Object.assign({}, t, {
            state: "ringing",
            finishedAt: t.endAt,
            remaining: 0
        });
    });
    return { list: list, fired: fired };
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

// What was saved, brought up to `now`: { list, nextId, ringNow, recent }.
// Timers that ended while the shell was off are ringing; `ringNow` says one
// ended less than STALE_MS ago (the alarm should sound), and `recent` lists
// the ringing timers worth a notification.
function restore(saved, savedNextId, now) {
    let nextId = savedNextId;
    let ringNow = false;
    const list = (Array.isArray(saved) ? saved : []).filter(t => t && t.id !== undefined).map(t => {
        const copy = Object.assign({}, t);
        if (copy.state === "running" && copy.endAt <= now) {
            copy.state = "ringing";
            copy.finishedAt = copy.endAt;
            copy.remaining = 0;
            if (now - copy.endAt < STALE_MS)
                ringNow = true;
        }
        nextId = Math.max(nextId, copy.id + 1);
        return copy;
    });
    return {
        list: list,
        nextId: nextId,
        ringNow: ringNow,
        recent: list.filter(t => t.state === "ringing" && now - t.finishedAt < STALE_MS)
    };
}
