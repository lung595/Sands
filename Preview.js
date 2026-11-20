.pragma library
.import "TimeParser.js" as TP
.import "Strings.js" as Strings

// What the launcher shows for a parsed result: one line saying exactly what
// Enter will create, so the user can trust the natural-language input.
// Pure functions, tested by tests/preview.test.js. `lang` is the interface
// language or locale name (Strings.langOf); English when it is left out.

// The parser keeps the label as typed (« pasta »); it is shown, and stored
// on the timer, with a capital so the preview matches what Enter creates.
function title(label) {
    return label ? label.charAt(0).toUpperCase() + label.slice(1) : "";
}

// When the result ends or rings, with « tomorrow » if it is not today.
function _ends(r, now, use24, lang) {
    var when = r.at || now + r.ms;
    var time = TP.formatTimeOfDay(when, use24);
    return TP.isTomorrow(when, now) ? Strings.tr("preview.tomorrow", lang, time) : time;
}

// « Pasta · 12 min · ends 12:42 », « Wake up · at 07:00 tomorrow »
function previewLine(r, now, use24, lang) {
    var ends = _ends(r, now, use24, lang);
    // A label-less result falls back to « Timer » / « Alarm », like everywhere else.
    var name = title(r.label || Strings.tr(r.kind === "at" ? "name.alarm" : "name.timer", lang));
    if (r.kind === "at")
        return Strings.tr("preview.at", lang, name, ends);
    var times = r.count > 1 ? r.count + " × " : "";
    return Strings.tr("preview.duration", lang, name, times + TP.formatHuman(r.ms), ends);
}

// Second line, under the preview: when it will ring, relative to now.
function ringsLine(r, now, use24, lang) {
    if (r.kind === "at")
        return Strings.tr("preview.ringsIn", lang, TP.formatRelative(r.ms));
    var line = Strings.tr("preview.ringsAt", lang, _ends(r, now, use24, lang));
    return r.capped ? line + " · " + Strings.tr("preview.capped", lang, TP.MAX_COUNT) : line;
}

// Short note the parser may attach to an empty result as « results.hint »
// (e.g. an unknown word). No story sets it yet: the parser story that adds
// unknown-word detection must use exactly this field name. Empty string when there is none.
function hintOf(results) {
    return results && typeof results.hint === "string" ? results.hint : "";
}
