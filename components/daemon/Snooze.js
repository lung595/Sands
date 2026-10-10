.pragma library

// Pure snooze choices (SN6), shared by the views, the settings and the tests:
// no QML, no storage, no side effects. The list comes in as data (from the
// settings) and is validated here, since a settings file can hold anything.

var DEFAULTS = [1, 5, 10];
// Longest single snooze, in minutes
var MAX_MINUTES = 120;
// Most choices offered, so the row stays readable
var MAX_CHOICES = 6;
// Raw entries read from the settings, so a huge list costs nothing to clean
var MAX_RAW = 50;

// A snooze length in whole minutes, or 0 when it is not valid
function minutes(value) {
    const n = typeof value === "number" || typeof value === "string" ? Number(value) : NaN;
    return Number.isInteger(n) && n >= 1 && n <= MAX_MINUTES ? n : 0;
}

// The valid, distinct, ascending choices from `raw`; the defaults when
// nothing valid is left
function clean(raw) {
    const seen = {};
    const out = [];
    for (const v of Array.isArray(raw) ? raw.slice(0, MAX_RAW) : []) {
        const m = minutes(v);
        if (m && !seen[m]) {
            seen[m] = true;
            out.push(m);
        }
    }
    out.sort((a, b) => a - b);
    return out.length ? out.slice(0, MAX_CHOICES) : DEFAULTS.slice();
}

// The choices to show: the last one picked first (if it is one of them),
// the others in ascending order
function ordered(raw, last) {
    const list = clean(raw);
    const m = minutes(last);
    return list.indexOf(m) > 0 ? [m].concat(list.filter(x => x !== m)) : list;
}

// The value to remember after a pick, or 0 when it is not an offered choice
function remember(raw, picked) {
    const m = minutes(picked);
    return clean(raw).indexOf(m) >= 0 ? m : 0;
}

// The snooze in ms for a pick, or 0 when invalid
function toMs(picked) {
    return minutes(picked) * 60000;
}
