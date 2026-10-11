.pragma library
.import "../../TimeParser.js" as TP

// Pure rules of the pinned favourites: which of the most started timers are
// shown, and the texts of a tile or a row. The views only draw what this
// returns. Tested by tests/pins.test.js.

// A timer is pinned from this many starts on, so a first timer is never a favourite
var MIN_STARTS = 2;
// Names Sands gives a timer that has none (Timers.displayLabel): pinning them
// would merge every unnamed timer into one, and restart an alarm as a duration (Q186)
var DEFAULT_NAMES = ["Timer", "Alarm"];
// Never more than this many are shown
var MAX_PINS = 3;

// Neutralises what is drawn from outside: no control character, no em or en
// dash (the owner does not want them on screen), at most 60 code points
function cleanName(name) {
    if (typeof name !== "string")
        return "";
    return Array.from(name.replace(/[\u0000-\u001f\u007f]/g, "").replace(/\s*[\u2013\u2014]\s*/g, " - ").trim()).slice(0, 60).join("");
}

// `list` is History.favourites(): [{ name, count, ms }]. Returns at most
// three pins { name, ms, duration, count, startedText, label } in the same
// order; anything damaged or started once is dropped.
function pins(list) {
    if (!Array.isArray(list))
        return [];
    const out = [];
    for (const f of list) {
        if (out.length >= MAX_PINS)
            break;
        if (!f || typeof f.count !== "number" || f.count < MIN_STARTS || !(f.ms >= 1000))
            continue;
        const name = cleanName(f.name);
        if (name === "" || DEFAULT_NAMES.indexOf(name) >= 0)
            continue;
        const duration = TP.formatHuman(f.ms);
        out.push({
            "name": name,
            "ms": f.ms,
            "duration": duration,
            "count": f.count,
            "startedText": "started " + f.count + " times",
            "label": "Start " + duration + " " + name
        });
    }
    return out;
}

// The sentence of the empty state
var EMPTY_TEXT = "The three timers you start most often will be pinned here.";
