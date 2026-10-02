.pragma library

// Pure timer logic, shared by TimerDaemon.qml and its tests: no QML, no
// clock of its own (the time is always passed in), no side effects.
//
// A timer is { id, state: "running" | "paused" | "ringing" | …, total,
// endAt (running), remaining (paused), finishedAt, label, kind, hue }.

// Milliseconds left at time `now` (negative once it has run out)
function remainingOf(t, now) {
    if (!t)
        return 0;
    if (t.state === "running")
        return t.endAt - now;
    if (t.state === "paused")
        return t.remaining;
    return (t.finishedAt || now) - now;
}

// 1 when just started, 0 when done, never outside [0, 1]
function progressOf(t, now) {
    if (!t || t.total <= 0)
        return 0;
    return Math.max(0, Math.min(1, remainingOf(t, now) / t.total));
}

// What a timer is called on screen: its label, else its kind
function displayLabel(t) {
    if (!t)
        return "";
    if (t.label)
        return t.label;
    return t.kind === "at" ? "Alarm" : "Timer";
}

// "Frecency": used often AND recently. A timer started 10 times last month
// ranks below yesterday's, not below one from a year ago.
function rankRecents(list, now) {
    const score = r => (r.uses || 1) / (1 + (now - (r.last || 0)) / 86400000 / 3);
    return list.slice().sort((a, b) => score(b) - score(a));
}

// The recents after starting `ms` named `label` at `now`: the same duration
// and name (any case) counts one more use, a new one is added; the 12 best
// are kept, best first.
function remember(recents, ms, label, now) {
    const key = (label || "").toLowerCase() + "|" + ms;
    let found = false;
    const list = recents.map(r => {
        if (((r.label || "").toLowerCase() + "|" + r.ms) !== key)
            return r;
        found = true;
        return Object.assign({}, r, {
            uses: (r.uses || 1) + 1,
            last: now,
            label: label || ""
        });
    });
    if (!found)
        list.push({
            ms: ms,
            label: label || "",
            uses: 1,
            last: now
        });
    return rankRecents(list, now).slice(0, 12);
}

// The first colour slot no running timer uses, else the next in turn
function freeHue(timers, hueCount) {
    for (let h = 0; h < hueCount; h++) {
        if (!timers.some(t => t.hue === h))
            return h;
    }
    return timers.length % hueCount;
}
