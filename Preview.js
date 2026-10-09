.pragma library
.import "TimeParser.js" as TP

// What the launcher shows for a parsed result: one line saying exactly what
// Enter will create, so the user can trust the natural-language input.
// Pure functions, tested by tests/preview.test.js.

var DEFAULT_LABEL = "Timer";
var DEFAULT_ALARM = "Alarm";

// The parser keeps the label as typed (« pasta »); the preview shows it
// with a capital, like a title.
function _title(label, fallback) {
    return label ? label.charAt(0).toUpperCase() + label.slice(1) : fallback;
}

// « Pasta · 12 min · ends 12:42 », « Wake up · at 07:00 tomorrow »
function previewLine(r, now, use24) {
    var when = r.at || now + r.ms;
    var end = TP.formatTimeOfDay(when, use24);
    var tomorrow = TP.isTomorrow(when, now) ? " tomorrow" : "";
    if (r.kind === "at")
        return _title(r.label, DEFAULT_ALARM) + " · at " + end + tomorrow;
    var times = r.count > 1 ? r.count + " × " : "";
    return _title(r.label, DEFAULT_LABEL) + " · " + times + TP.formatHuman(r.ms) + " · ends " + end + tomorrow;
}

// Second line, under the preview: when it will ring, relative to now.
function ringsLine(r, now, use24) {
    var when = r.at || now + r.ms;
    var tomorrow = TP.isTomorrow(when, now) ? " tomorrow" : "";
    if (r.kind === "at")
        return "Rings in " + TP.formatRelative(r.ms);
    return "Rings at " + TP.formatTimeOfDay(when, use24) + tomorrow + (r.capped ? " · at most 20 at once" : "");
}

// Short note the parser may attach to an empty result (« results.hint »,
// e.g. an unknown word). Empty string when there is none.
function hintOf(results) {
    return results && typeof results.hint === "string" ? results.hint : "";
}
