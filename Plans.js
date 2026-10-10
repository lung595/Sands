.pragma library

// Plan parser (French / English): focus cycles and chained timers.
//
// parse("4x 25/5") returns a plan, or null when the text is not clearly one,
// so that the single-timer parser (TimeParser.js) keeps its behaviour:
//   { kind: "cycle", repeats: 4,
//     phases: [{ label: "Focus", ms: 1500000 }, { label: "Break", ms: 300000 }] }
//   { kind: "chain", repeats: 1,
//     phases: [{ label: "pasta", ms: 600000 }, { label: "sauce", ms: 300000 }] }
// `phases` is one round; the plan plays it `repeats` times. A chain phase
// without a name has the label "" (the caller picks a default).
// Cycle forms: « 4x 25/5 », « 25/5 x4 », « pomodoro 4 cycles 25/5 »,
// « 4 fois 25m/5m », « 25/5 4 times ». Chain forms: « pasta 10 then sauce 5 »,
// « 10 min pates puis 5 min sauce », « a 10 > b 5 ». A bare number is minutes.

// Same bounds as the single-timer parser: one phase is at most 100 h
var MAX_MS = 100 * 3600 * 1000;
// A plan never plays more than this many phases in total
var MAX_PHASES = 40;
var MAX_REPEATS = 20;
// Chained timers in one phrase
var MAX_CHAIN = 10;
// Same cap as the single-timer parser: bounds the regex work on IPC input
var MAX_INPUT = 200;
var MAX_LABEL = 60;

var U_HOUR = "h|hr|hrs|heures?|hours?";
var U_MIN = "min|mins|minutes?|mn|m";
var U_SEC = "s|sec|secs|secondes?|seconds?";
// Groups: 1 number, 2 hour unit, 3 minutes after the hour (« 1h30 »),
// 4 minute unit, 5 second unit. No unit means minutes.
var DUR = "(?<![a-z0-9.,])(\\d+(?:[.,]\\d+)?)\\s*(?:(" + U_HOUR + ")(?![a-z])(?:\\s*(\\d+)(?![\\d.,]\\d?)(?:\\s*(?:" + U_MIN + ")(?![a-z]))?)?|(" + U_MIN + ")(?![a-z])|(" + U_SEC + ")(?![a-z]))?";
var COUNT_WORD = "x|\\*|×|cycles?(?:\\s+(?:of|de|d'))?|fois|times|rounds?|sets?";
var RE_DUR = new RegExp(DUR, "g");
var RE_PAIR = DUR + "\\s*/\\s*" + DUR.replace("(?<![a-z0-9.,])", "");
var RE_COUNT_FIRST = new RegExp("^(?:pomodoro\\s+|focus\\s+)?(\\d+)\\s*(?:" + COUNT_WORD + ")\\s*(?:of\\s+|de\\s+)?" + RE_PAIR + "$");
var RE_COUNT_AFTER = new RegExp("^(?:pomodoro\\s+|focus\\s+)?" + RE_PAIR + "\\s*(?:(?:x|\\*|×)\\s*(\\d+)|(\\d+)\\s*(?:times|fois|cycles?|rounds?))$");
var RE_SPLIT = /\s*(?:->|=>|>|;|,(?!\d)|\b(?:and then|et puis|et ensuite|then|puis|ensuite)\b)\s*/;
var RE_LEAD = /^(?:(?:for|pour|de|d['’]|during|pendant|in|dans|timer|minuteur)\s*)+/i;
var RE_TRAIL = /(?:\s+(?:for|pour|de|d['’]|during|pendant|in|dans))+$/i;

// Lowercase, no accents; one character in, one character out, so positions
// stay aligned with the original text the labels are cut from
function normalize(text) {
    var out = "";
    for (var i = 0; i < text.length; i++) {
        var c = text.charAt(i).toLowerCase();
        if (c.length !== 1)
            c = text.charAt(i);
        if (c === "’" || c === "‘" || c === "`")
            c = "'";
        out += c.normalize ? c.normalize("NFD").charAt(0) : c;
    }
    return out;
}

// Milliseconds of one DUR match whose groups start at `at`, or NaN
function durationMs(m, at) {
    var n = parseFloat(m[at].replace(",", "."));
    var ms;
    if (m[at + 1] !== undefined)
        ms = n * 3600000 + (m[at + 2] !== undefined ? parseInt(m[at + 2], 10) * 60000 : 0);
    else if (m[at + 4] !== undefined)
        ms = n * 1000;
    else
        ms = n * 60000;
    ms = Math.round(ms);
    return ms >= 1000 && ms <= MAX_MS ? ms : NaN;
}

function cleanLabel(text) {
    var s = text.replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim();
    s = s.replace(RE_LEAD, "").replace(RE_TRAIL, "").trim();
    return s.length > MAX_LABEL ? s.slice(0, MAX_LABEL).trim() : s;
}

function plan(kind, phases, repeats) {
    if (repeats < 1 || repeats > MAX_REPEATS || phases.length * repeats > MAX_PHASES)
        return null;
    return { kind: kind, repeats: repeats, phases: phases };
}

function parseCycle(work) {
    var m = RE_COUNT_FIRST.exec(work);
    var repeats, at;
    if (m) {
        repeats = parseInt(m[1], 10);
        at = 2;
    } else {
        m = RE_COUNT_AFTER.exec(work);
        if (!m)
            return null;
        repeats = parseInt(m[11] !== undefined ? m[11] : m[12], 10);
        at = 1;
    }
    var focus = durationMs(m, at), pause = durationMs(m, at + 5);
    if (isNaN(focus) || isNaN(pause))
        return null;
    return plan("cycle", [{ label: "Focus", ms: focus }, { label: "Break", ms: pause }], repeats);
}

// One chain step: exactly one duration, the rest of the words is its name
function parseStep(original, work) {
    RE_DUR.lastIndex = 0;
    var m = RE_DUR.exec(work);
    if (!m)
        return null;
    var end = m.index + m[0].length;
    RE_DUR.lastIndex = end;
    if (RE_DUR.exec(work))
        return null;
    var ms = durationMs(m, 1);
    if (isNaN(ms))
        return null;
    return { label: cleanLabel(original.slice(0, m.index) + " " + original.slice(end)), ms: ms };
}

function parseChain(original, work) {
    var parts = work.split(RE_SPLIT);
    if (parts.length < 2 || parts.length > MAX_CHAIN)
        return null;
    var phases = [];
    var pos = 0;
    for (var i = 0; i < parts.length; i++) {
        // The split removed separators of unknown length: find the part again
        var start = work.indexOf(parts[i], pos);
        pos = start + parts[i].length;
        var step = parseStep(original.slice(start, pos), parts[i]);
        if (!step)
            return null;
        phases.push(step);
    }
    return plan("chain", phases, 1);
}

function parse(input) {
    if (typeof input !== "string" || input.length > MAX_INPUT)
        return null;
    var original = input.trim();
    var work = normalize(original);
    if (!/\d/.test(work))
        return null;
    return parseCycle(work) || parseChain(original, work);
}
