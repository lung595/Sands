.pragma library
.import "TimeParser.js" as TimeParser

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
// « 10 min pates puis 5 min sauce », « tea 3 > toast 2 ». A bare number is minutes.

// Bounds and unit spellings come from the single-timer parser: one source
var MAX_MS = TimeParser.MAX_MS;
var MAX_INPUT = TimeParser.MAX_INPUT;
var MAX_LABEL = TimeParser.MAX_LABEL;
var U_HOUR = TimeParser.U_HOUR;
var U_MIN = TimeParser.U_MIN;
var U_SEC = TimeParser.U_SEC;
// A plan never plays more than this many phases in total
var MAX_PHASES = 40;
var MAX_REPEATS = 20;
// Chained timers in one phrase
var MAX_CHAIN = 10;

// A duration may not start inside a word, a version or a decimal number
var DUR_START = "(?<![a-z0-9.,:])";
// Capture groups of one duration: 1 number, 2 hour unit, 3 minutes after the
// hour (« 1h30 »), 4 minute unit, 5 second unit
var DUR_GROUPS = 5;
var NUMBER = "(\\d+(?:[.,]\\d+)?)";
var HOUR_PART = "(" + U_HOUR + ")(?![a-z])(?:\\s*(\\d+)(?![\\d.,]\\d?)(?:\\s*(?:" + U_MIN + ")(?![a-z]))?)?";
// No unit means minutes, but only when nothing is glued to the number:
// « 5pm », « 10kg », « 1.5.2 » and « 1e3 » are not durations
var DUR_CORE = NUMBER + "(?:\\s*(?:" + HOUR_PART + "|(" + U_MIN + ")(?![a-z])|(" + U_SEC + ")(?![a-z]))|(?![a-z0-9:]|[.,]\\d))";
var PAIR = DUR_START + DUR_CORE + "\\s*/\\s*" + DUR_CORE;
var COUNT_WORD = "x|\\*|×|cycles?(?:\\s+(?:of|de|d'))?|fois|times|rounds?|sets?";
var RE_DUR = new RegExp(DUR_START + DUR_CORE, "g");
var RE_COUNT_FIRST = new RegExp("^(?:pomodoro\\s+|focus\\s+)?(\\d+)\\s*(?:" + COUNT_WORD + ")\\s*(?:of\\s+|de\\s+)?" + PAIR + "$");
var RE_COUNT_AFTER = new RegExp("^(?:pomodoro\\s+|focus\\s+)?" + PAIR + "\\s*(?:(?:x|\\*|×)\\s*(\\d+)|(\\d+)\\s*(?:times|fois|cycles?|rounds?))$");
var RE_SPLIT = /\s*(?:->|=>|>|;|,(?!\d)|\b(?:and then|et puis|et ensuite|then|puis|ensuite)\b)\s*/;
// A comma or semicolon only separates named steps: « 1 h, 30 min » is one
// composite duration that the single-timer parser reads
var RE_LIST_MARK = /;|,(?!\d)/;
// A step that names a time of day is an alarm, not a plan step
var RE_CLOCK = /@|(?:^|\s)(?:at|a|vers|until|jusqu'a)\s*\d|\b(?:am|pm)\b/;
// Day words (« demain », « ce soir ») come from the single-timer parser; noon
// and midnight are alarms too
var RE_DAY_WORD = new RegExp("(?:^|[^a-z])(?:midi|noon|minuit|midnight|" +
    Object.keys(TimeParser.DAY_WORDS).join("|") + ")(?![a-z])");
// A filler word only counts as one when it is a whole word, so « dessert »
// keeps its name; « d' » may stay glued to the next word
var RE_LEAD = /^(?:(?:for|pour|de|during|pendant|in|dans|timer|minuteur)(?=\s|$)\s*|d['’]\s*)+/i;
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
    if (s.length <= MAX_LABEL)
        return s;
    // Do not cut an emoji (surrogate pair) in two
    var cut = /[\ud800-\udbff]/.test(s.charAt(MAX_LABEL - 1)) ? MAX_LABEL - 1 : MAX_LABEL;
    return s.slice(0, cut).trim();
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
        repeats = parseInt(m[2 * DUR_GROUPS + 1] !== undefined ? m[2 * DUR_GROUPS + 1] : m[2 * DUR_GROUPS + 2], 10);
        at = 1;
    }
    var focus = durationMs(m, at), pause = durationMs(m, at + DUR_GROUPS);
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
    if (parts.length < 2 || parts.length > MAX_CHAIN || RE_CLOCK.test(work) || RE_DAY_WORD.test(work))
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
    // Unnamed steps are only allowed between words or arrows (« 10 then 5 »)
    if (RE_LIST_MARK.test(work) && phases.some(function (p) { return p.label === ""; }))
        return null;
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
