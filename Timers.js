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

// What a timer is called in the saved history: its label as typed, else its
// kind. Never capitalised: the journal and the favourites group names as they
// are, so « thé » saved before and after the on-screen capital stays one name.
function savedName(t) {
    if (!t)
        return "";
    if (t.label)
        return t.label;
    return t.kind === "at" ? "Alarm" : "Timer";
}

// What a timer is called on screen: its saved name with a capital (« thé »
// typed shows « Thé », as the launcher's preview rows write it)
function displayLabel(t) {
    const name = savedName(t);
    return name.charAt(0).toUpperCase() + name.slice(1);
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

// Emoji in a name: the pictographs (U+1F000..1FAFF, which holds flags and
// skin tones too, and the symbol blocks drawn as emoji) with what joins or
// dresses them (zero-width joiner, variation selector, keycap, tags). The
// interface shows Material Symbols only, never emoji. The `u` flag with
// \u{…} code points is what the QML engine accepts (it has no \p{…}).
var EMOJI_RE = new RegExp("(?:[\\u{1F000}-\\u{1FAFF}\\u{2600}-\\u{27BF}\\u{2B00}-\\u{2BFF}\\u{231A}\\u{231B}\\u{23E9}-\\u{23FA}\\u{3030}\\u{303D}\\u{3297}\\u{3299}][\\u{FE0F}\\u{20E3}\\u{E0020}-\\u{E007F}]*)(?:\\u{200D}[\\u{1F000}-\\u{1FAFF}\\u{2600}-\\u{27BF}\\u{2B00}-\\u{2BFF}][\\u{FE0F}\\u{20E3}\\u{E0020}-\\u{E007F}]*)*|[\\u{FE0F}\\u{20E3}]", "gu");

// `s` without its emoji, spaces collapsed, at most `maxLabel` characters
// (never cutting a surrogate pair), trimmed. "" when nothing is left.
function stripEmoji(s, maxLabel) {
    let out = String(s === undefined || s === null ? "" : s).replace(EMOJI_RE, " ").replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim();
    if (maxLabel > 0 && out.length > maxLabel)
        out = out.slice(0, /[\ud800-\udbff]/.test(out.charAt(maxLabel - 1)) ? maxLabel - 1 : maxLabel);
    return out.trim();
}

// The name a timer gets when its own was nothing but emoji, in the shell's
// language ("fr_FR" -> "Minuteur", anything else -> "Timer")
function fallbackName(locale) {
    return /^fr/i.test(String(locale || "")) ? "Minuteur" : "Timer";
}

// A saved or typed name, cleaned: emoji gone; a name that was only emoji
// becomes `fallback`; an empty name stays empty (the timer shows its kind)
function cleanName(s, maxLabel, fallback) {
    const out = stripEmoji(s, maxLabel);
    return out === "" && String(s || "").trim() !== "" ? fallback : out;
}
