.pragma library
.import "TimeParser.js" as TP
.import "Timers.js" as Timers

// What the launcher shows for a parsed result: one line saying exactly what
// Enter will create, so the user can trust the natural-language input.
// Pure functions, tested by tests/preview.test.js.

// The parser keeps the label as typed (« pasta »); it is shown, and stored
// on the timer, with a capital so the preview matches what Enter creates.
function title(label) {
    return label ? label.charAt(0).toUpperCase() + label.slice(1) : "";
}

// When the result ends or rings, and the « tomorrow » suffix if it is not today.
function _ends(r, now, use24) {
    var when = r.at || now + r.ms;
    return { time: TP.formatTimeOfDay(when, use24), tomorrow: TP.isTomorrow(when, now) ? " tomorrow" : "" };
}

// « Pasta · 12 min · ends 12:42 », « Wake up · at 07:00 tomorrow »
function previewLine(r, now, use24) {
    var e = _ends(r, now, use24);
    // A label-less result falls back to « Timer » / « Alarm », like everywhere else.
    var name = title(Timers.displayLabel({ label: r.label, kind: r.kind }));
    if (r.kind === "at")
        return name + " · at " + e.time + e.tomorrow;
    var times = r.count > 1 ? r.count + " × " : "";
    return name + " · " + times + TP.formatHuman(r.ms) + " · ends " + e.time + e.tomorrow;
}

// Second line, under the preview: when it will ring, relative to now.
function ringsLine(r, now, use24) {
    if (r.kind === "at")
        return "Rings in " + TP.formatRelative(r.ms);
    var e = _ends(r, now, use24);
    return "Rings at " + e.time + e.tomorrow + (r.capped ? " · at most 20 at once" : "");
}

// Short note the parser may attach to an empty result as « results.hint »
// (e.g. an unknown word). No story sets it yet: the parser story that adds
// unknown-word detection must use exactly this field name. Empty string when there is none.
function hintOf(results) {
    return results && typeof results.hint === "string" ? results.hint : "";
}
