.pragma library
.import "lang/en.js" as En
.import "lang/fr.js" as Fr
.import "Timers.js" as Timers
.import "TimeFormat.js" as TimeFormat

// Free-form input parser (French / English) for starting a timer.
//
// parse("timer 1h30 pâtes", now, { keyword: false }) returns a list of
// candidates, most likely first:
//   [{ kind: "duration", ms: 5400000, label: "pâtes" }]
//   [{ kind: "at", at: <epoch ms>, ms: <ms until that time>, label: "" }]
// An empty list means "this is not a timer": the launcher then stays
// silent for every other search. Every list carries a string `hint`: a short
// message when the user clearly asked for a timer but a word was not
// understood, "" otherwise (see Preview.hintOf).
//
// A duration can be repeated: « 4x 1h », « 4*1h », « 1h x4 » → count: 4
// (four timers of one hour).
//
// The words come from the language packs (lang/*.js): PACKS lists them and
// grammar() builds every regex from their union, once. parse() runs the
// named stages of STAGES in order over one reading (see newReading); each
// stage reads what it knows and consumes it, so the next ones never see it
// again. What is left is the label.

var MAX_MS = 100 * 3600 * 1000;
var MAX_COUNT = 20;
// Nobody types more than this for a timer; the parser's cost grows with the
// square of the length, so a huge text (IPC, launcher) would freeze the shell
var MAX_INPUT = 200;
// A label longer than this would not fit anywhere it is shown
var MAX_LABEL = 60;
// The longest bare number read as minutes (« pasta 12 »): above this it is
// more likely a name or a version than a duration.
var MAX_BARE_MINUTES = 180;

var PACKS = [En, Fr];

// ---------------------------------------------------------------------------
// Grammar: the regexes built from the packs
// ---------------------------------------------------------------------------

// Every entry of `key` in the packs, each once
function gather(packs, key) {
    var out = [];
    for (var i = 0; i < packs.length; i++) {
        var list = packs[i][key] || [];
        for (var j = 0; j < list.length; j++) {
            if (out.indexOf(list[j]) < 0)
                out.push(list[j]);
        }
    }
    return out;
}

// The objects `key` of the packs merged into one
function merge(packs, key) {
    var out = {};
    for (var i = 0; i < packs.length; i++) {
        var obj = packs[i][key] || {};
        for (var k in obj)
            out[k] = obj[k];
    }
    return out;
}

// A regex alternation of the words, longest first so a short word never
// hides a longer one that starts the same way
function alt(words) {
    return words.slice().sort(function (a, b) {
        return b.length - a.length;
    }).join("|");
}

// The parser's tables and regexes for a list of packs
function grammar(packs) {
    var g = { packs: packs };
    g.numbers = merge(packs, "NUMBERS");
    var articles = gather(packs, "ARTICLES");
    var tens = [], units = [], single = [], ones = ["1"];
    for (var w in g.numbers) {
        var v = g.numbers[w];
        if (v >= 20 && v % 10 === 0) {
            tens.push(w);
        } else {
            single.push(w);
            if (v >= 1 && v <= 9 && articles.indexOf(w) < 0)
                units.push(w);
        }
        if (v === 1)
            ones.push(w);
    }
    g.numberLinks = gather(packs, "NUMBER_LINKS");
    var links = g.numberLinks.length ? "(?:(?:" + alt(g.numberLinks) + ")[- ])?" : "";
    var extra = gather(packs, "NUMBER_EXTRA");
    var wordnum = "(?:(?:" + alt(tens) + ")(?:[- ]" + links + "(?:" + alt(units) + "))?|"
        + (extra.length ? alt(extra) + "|" : "") + alt(single) + ")";
    var NUM = "(\\d+(?:[.,]\\d+)?|" + wordnum + ")";

    var hours = g.uHour = alt(gather(packs, "HOURS"));
    var minutes = g.uMin = alt(gather(packs, "MINUTES"));
    var seconds = g.uSec = alt(gather(packs, "SECONDS"));
    var anyUnit = hours + "|" + minutes + "|" + seconds;
    var UNIT = "(" + anyUnit + ")";
    var quarter = gather(packs, "QUARTER");
    var HALF = "(?:\\s*(?:" + alt(gather(packs, "AND")) + ")\\s*(" + alt(gather(packs, "HALF").concat(quarter)) + "))?";
    g.quarterWord = new RegExp("^(?:" + alt(quarter) + ")$");

    var elisions = function (list, after) {
        return list.map(function (e) {
            return "|" + after(e);
        }).join("");
    };
    g.context = new RegExp("^\\s*(?:" + gather(packs, "CONTEXT").join("|") + ")(?![a-z])(?:\\s+(?:"
        + alt(gather(packs, "CONTEXT_LINKS")) + ")(?![a-z])"
        + elisions(gather(packs, "CONTEXT_ELISIONS"), function (e) { return "\\s+" + e; }) + ")?");
    g.connector = new RegExp("^(?:(?:" + alt(gather(packs, "LABEL_LINKS")) + ")\\s+"
        + elisions(gather(packs, "LABEL_ELISIONS"), function (e) { return e + "\\s*"; }) + ")", "i");
    g.keyword = new RegExp("^\\s*(?:" + alt(gather(packs, "KEYWORDS")) + ")(?![a-z])");

    // Labels: small words and punctuation trimmed from both ends
    var edge = elisions(gather(packs, "LABEL_ELISIONS_EDGE"), function (e) { return e; });
    g.labelHead = new RegExp("^(?:(?:" + alt(gather(packs, "LABEL_HEAD")) + ")(?=\\s|$)" + edge + "|:|-|–|—|,|\\.|!|\\?|…|;)\\s*", "i");
    g.labelTail = new RegExp("\\s*(?:(?:^|\\s)(?:" + alt(gather(packs, "LABEL_TAIL")) + ")" + edge + "|:|-|–|—|,|\\.|!|\\?|…|;)$", "i");

    // Day words fix the date or the half of the day of a clock time
    g.dayWords = merge(packs, "DAY_WORDS");
    g.day = new RegExp("(?:^|[^a-z])(" + alt(Object.keys(g.dayWords)) + ")(?![a-z])");
    var pm = gather(packs, "PERIOD_PM");
    var period = g.period = alt(gather(packs, "PERIOD_AM").concat(pm));
    g.pm = new RegExp("^(?:" + alt(pm) + ")$");
    // 1 preposition, 2 noon, 3 midnight, 4 hour, 5 « h » word, 6 minutes after h,
    // 7 minutes after a colon, 8 period
    g.clock = new RegExp("(?:^|[\\s\\u0000])(?:(" + alt(gather(packs, "CLOCK_PREPOSITIONS")) + ")\\s*)?(?:("
        + alt(gather(packs, "NOON")) + ")|(" + alt(gather(packs, "MIDNIGHT")) + ")|"
        + "(\\d{1,2})(?:\\s*(" + alt(gather(packs, "CLOCK_HOURS")) + ")\\s*(\\d{2})?|:(\\d{2}))?(?:\\s*(" + period + "))?)(?![\\w:])", "g");

    // A bare hour followed by a unit is a duration: « pasta a 12 min »
    g.unitAhead = new RegExp("^\\s*(?:" + anyUnit + ")(?![a-z])");
    g.unitWord = new RegExp("^(?:" + anyUnit + ")$");
    g.hourWord = new RegExp("^(?:" + hours + ")$");
    g.minuteWord = new RegExp("^(?:" + minutes + ")$");
    g.afterNumber = new RegExp("(^|[^a-z0-9.,'])" + NUM + "\\s*([a-z]{3,})(?![a-z])", "g");
    g.typoUnits = gather(packs, "TYPO_UNITS");
    g.typoAbbreviations = gather(packs, "TYPO_ABBREVIATIONS");
    g.typoStopwords = gather(packs, "TYPO_STOPWORDS");

    // Durations
    g.fraction = new RegExp("(?:^|[^\\d/.,])(\\d{1,2})\\s*/\\s*(\\d{1,2})\\s*(?:" + alt(gather(packs, "FRACTION_HOUR")) + ")(?![a-z])");
    g.halfHour = new RegExp("(?:^|[^a-z])((?:(?:" + alt(ones) + ")\\s+)?(?:" + alt(gather(packs, "HALF_HOUR")) + "))(?![a-z])");
    g.quarterHour = new RegExp("(?:^|[^a-z0-9])((?:" + NUM + "\\s+)?(?:" + alt(gather(packs, "QUARTER_HOUR")) + "))(?![a-z])");
    g.component = new RegExp("(?:^|[^a-z0-9.,'])" + NUM + "\\s*" + UNIT + "(?![a-z])" + HALF, "g");
    g.chain = new RegExp("^\\s*" + NUM + "\\s*" + UNIT + "(?![a-z])" + HALF);
    // Implicit remainder, unless it carries its own unit (« 1h 30min » is read separately).
    g.remainder = new RegExp("^\\s*(\\d{1,2})(?![\\d.,:]|\\s*" + UNIT + "(?![a-z]))");

    var approx = alt(gather(packs, "APPROX"));
    g.approxAfter = new RegExp("\\u0000\\s*(" + approx + ")(?![a-z])");
    g.approxBefore = new RegExp("(?:^|[^a-z])(" + approx + ")\\s*\\u0000");
    return g;
}

// Built once: parse runs on every keystroke.
var GRAMMAR = grammar(PACKS);
// Every pack's units, periods (« pm », « du soir ») and day words, for Plans.js
var U_HOUR = GRAMMAR.uHour;
var U_MIN = GRAMMAR.uMin;
var U_SEC = GRAMMAR.uSec;
var PERIOD = GRAMMAR.period;
var DAY_WORDS = GRAMMAR.dayWords;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Lowercase, no accents, straight apostrophes. Each character maps to
// exactly one character, so positions stay aligned with the original
// input, from which the label is extracted as it was typed.
function normalize(text) {
    var out = "";
    for (var i = 0; i < text.length; i++) {
        var c = text.charAt(i).toLowerCase();
        if (c.length !== 1)
            c = text.charAt(i);
        if (c === "’" || c === "‘" || c === "`")
            c = "'";
        var base = c.normalize ? c.normalize("NFD").charAt(0) : c;
        out += base;
    }
    return out;
}

function wordToNumber(w, g) {
    g = g || GRAMMAR;
    w = w.trim();
    if (/^\d/.test(w))
        return parseFloat(w.replace(",", "."));
    if (g.numbers[w] !== undefined)
        return g.numbers[w];
    var parts = w.split(/[- ]+/).filter(function (p) {
        return g.numberLinks.indexOf(p) < 0;
    });
    var total = 0;
    for (var i = 0; i < parts.length; i++) {
        if (g.numbers[parts[i]] === undefined)
            return NaN;
        total += g.numbers[parts[i]];
    }
    return total;
}

// True when a and b differ by exactly one swapped pair of adjacent letters.
function isSwap(a, b) {
    if (a.length !== b.length)
        return false;
    var i = 0;
    while (i < a.length && a.charAt(i) === b.charAt(i))
        i++;
    return i + 1 < a.length && a.charAt(i) === b.charAt(i + 1) && a.charAt(i + 1) === b.charAt(i)
        && a.substring(i + 2) === b.substring(i + 2);
}

// True when a and b differ by one substituted letter.
function isSubstitution(a, b) {
    if (a.length !== b.length)
        return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
        if (a.charAt(i) !== b.charAt(i))
            diff++;
    }
    return diff === 1;
}

// True when longer is shorter plus one letter somewhere.
function isMissingLetter(shorter, longer) {
    if (longer.length !== shorter.length + 1)
        return false;
    var i = 0;
    while (i < shorter.length && shorter.charAt(i) === longer.charAt(i))
        i++;
    return shorter.substring(i) === longer.substring(i + 1);
}

// The short unit a word one letter off a unit stands for, or "". Short words
// are matched strictly: « four » and « pour » are one letter from « hour ».
// A dropped or substituted letter must not be the first one: « jours »,
// « cours » and « tours » are one letter from « hours » but are French words
// for days, classes and laps. Three-letter units (« min », « sec ») are too
// close to ordinary words (« men », « sex ») to allow anything but two
// swapped letters: « mni », « esc ».
function typoUnit(word, g) {
    g = g || GRAMMAR;
    var i, w;
    if (g.typoStopwords.indexOf(word) >= 0)
        return "";
    for (i = 0; i < g.typoAbbreviations.length; i++) {
        if (isSwap(word, g.typoAbbreviations[i][0]))
            return g.typoAbbreviations[i][1];
    }
    for (i = 0; i < g.typoUnits.length; i++) {
        w = g.typoUnits[i][0];
        if (isSwap(word, w))
            return g.typoUnits[i][1];
        if (word.charAt(0) !== w.charAt(0))
            continue;
        if ((word.length >= 5 && isSubstitution(word, w))
                || (word.length >= 4 && isMissingLetter(word, w))
                || (word.length >= 6 && isMissingLetter(w, word)))
            return g.typoUnits[i][1];
    }
    return "";
}

function unitMs(u, g) {
    g = g || GRAMMAR;
    if (g.hourWord.test(u))
        return 3600000;
    if (g.minuteWord.test(u))
        return 60000;
    return 1000;
}

function nextOccurrence(h, m, now) {
    var d = new Date(now);
    d.setHours(h, m, 0, 0);
    if (d.getTime() <= now + 1000)
        d.setDate(d.getDate() + 1);
    return d.getTime();
}

// Replaces a consumed range with \0: nothing can read it again,
// and cleanLabel knows it is not part of the label.
function consume(work, start, end) {
    return work.substring(0, start) + new Array(end - start + 1).join("\u0000") + work.substring(end);
}

// What is left of the original text once the consumed parts are gone: no
// emoji, no small words or punctuation at either end.
function cleanLabel(original, work, g) {
    g = g || GRAMMAR;
    var kept = "";
    for (var i = 0; i < original.length; i++)
        kept += work.charAt(i) === "\u0000" ? " " : original.charAt(i);
    kept = Timers.stripEmoji(kept, 0);
    var prev;
    do {
        prev = kept;
        kept = kept.replace(g.labelHead, "").replace(g.labelTail, "").trim();
    } while (kept !== prev);
    return kept;
}

// True when a text is too long to be read as a timer (see MAX_INPUT)
function tooLong(input) {
    return String(input || "").length > MAX_INPUT;
}

// The hour and minutes one clock match stands for, or null when it is not a
// clock time. A bare hour needs a preposition (« at 7 »): without one « 7 »
// could be anything (« room 12 »), and « a 12 min » is a duration.
function clockOfMatch(m, rest, dayInfo, g) {
    if (m[2])
        return { hh: 12, mm: 0 };
    if (m[3])
        return { hh: 0, mm: 0 };
    var hh = parseInt(m[4]);
    var mm = parseInt(m[6] || m[7] || "0");
    var explicit = m[5] || m[7] !== undefined || m[8];
    if (!m[1] && !(explicit && (m[8] || dayInfo)))
        return null;
    if (!explicit && g.unitAhead.test(rest))
        return null;
    if (m[8]) {
        // « at 13pm » keeps its 24 h reading; without a preposition it is no hour
        if ((hh < 1 || hh > 12) && !m[1])
            return null;
        if (hh >= 1 && hh <= 12)
            hh = (hh % 12) + (g.pm.test(m[8].replace(/\s+/g, " ")) ? 12 : 0);
    } else if (dayInfo && dayInfo.pm && hh >= 1 && hh <= 11) {
        hh += 12;
    } else if (dayInfo && dayInfo.night && hh === 12) {
        hh = 0;
    }
    return hh > 23 || mm > 59 ? null : { hh: hh, mm: mm };
}

// The clock time in the text, or null: { at: epoch ms, spans: [[start, end], …] }
// where the spans (the time and its day word) are to be consumed. Every match
// is tried, because a number earlier in the text (« room 12 at 7pm ») must not
// hide the real time. A bare hour is the next occurrence of that hour within
// 24 h; « tomorrow » is the calendar day after today.
function readClockTime(work, now, g) {
    g = g || GRAMMAR;
    var day = g.day.exec(work);
    var dayInfo = day ? g.dayWords[day[1]] : null;
    var m, clock = null;
    g.clock.lastIndex = 0;
    while ((m = g.clock.exec(work)) !== null) {
        clock = clockOfMatch(m, work.substring(m.index + m[0].length), dayInfo, g);
        if (clock)
            break;
    }
    if (!clock)
        return null;
    var hh = clock.hh, mm = clock.mm;
    var at;
    if (dayInfo && dayInfo.shift) {
        var d = new Date(now);
        d.setDate(d.getDate() + dayInfo.shift);
        d.setHours(hh, mm, 0, 0);
        at = d.getTime();
    } else {
        at = nextOccurrence(hh, mm, now);
    }
    var spans = [[m.index, m.index + m[0].length]];
    if (dayInfo)
        spans.push([day.index + day[0].indexOf(day[1]), day.index + day[0].indexOf(day[1]) + day[1].length]);
    return { at: at, spans: spans };
}

// Attaches the message for the launcher to a result list (see Preview.hintOf).
function withHint(list, hint) {
    list.hint = hint;
    return list;
}

function noResult(hint) {
    return withHint([], hint);
}

// « Unknown word », when a timer was clearly asked for (keyword or context
// verb) but nothing could be read from the text: the first word left over.
function unknownWordHint(original, work, g) {
    var word = /[^\s\u0000]+/.exec(cleanLabel(original, work, g));
    return word ? "Unknown word « " + word[0].substring(0, 20) + " »" : "";
}

// ---------------------------------------------------------------------------
// Stages of parse(), in order. Each one reads the reading `r` (see
// newReading), consumes what it understood from r.work (so later stages and
// the label never see it) and records it.
// ---------------------------------------------------------------------------

// One parse in progress. `original` keeps the text as typed (the label comes
// from it), `work` is its normalized twin, consumed as the stages go.
function newReading(input, now, options, g) {
    var original = String(input);
    return {
        g: g, now: now,
        original: original, work: normalize(original),
        keyword: !!options.keyword, context: false,
        count: 1, capped: false,
        target: null, total: 0, found: false, clockLike: null
    };
}

// « 20 mni », « 1 heur »: a misspelled unit right after a number is replaced
// by the unit itself, in the normalized text and in the original alike so the
// two stay aligned (the replaced word never reaches the label).
function fixUnitTypos(r) {
    var re = r.g.afterNumber;
    var fixes = [];
    var m;
    re.lastIndex = 0;
    while ((m = re.exec(r.work))) {
        var word = m[m.length - 1];
        if (r.g.unitWord.test(word))
            continue;
        var unit = typoUnit(word, r.g);
        if (unit)
            fixes.push({ start: m.index + m[0].length - word.length, end: m.index + m[0].length, unit: unit });
    }
    for (var i = fixes.length - 1; i >= 0; i--) {
        var f = fixes[i];
        r.original = r.original.substring(0, f.start) + f.unit + r.original.substring(f.end);
        r.work = r.work.substring(0, f.start) + f.unit + r.work.substring(f.end);
    }
}

// Verbs that only introduce the request: « rappelle-moi de », « remind me to »,
// « set a timer for », « mets un minuteur de ». Dropped, never in the label.
function readContext(r) {
    var m = r.g.context.exec(r.work);
    if (m) {
        r.context = true;
        r.keyword = true;
        r.work = consume(r.work, 0, m[0].length);
    }
}

// « timer », « minuteur »… at the start
function readKeyword(r) {
    var m = r.g.keyword.exec(r.work);
    if (m) {
        r.keyword = true;
        r.work = consume(r.work, 0, m[0].length);
    }
}

// Repeat: « 4x 1h », « 4 * 1h », « 4×1h » at the start, or « 1h x4 » at the end.
function readRepeat(r) {
    var m = /^[\s\u0000]*(\d{1,2})\s*[x×*](?=\s|\d|$)/.exec(r.work) || /(?:^|\s)[x×*]\s*(\d{1,2})\s*$/.exec(r.work);
    if (!m)
        return;
    var n = parseInt(m[1]);
    if (n >= 1) {
        r.count = Math.min(n, MAX_COUNT);
        r.capped = n > MAX_COUNT;
        r.work = consume(r.work, m.index, m.index + m[0].length);
    }
}

// Clock time: « à 18h », « at 6pm », « vers midi », « demain 8h », « ce soir à 9h ».
function readClock(r) {
    var clock = readClockTime(r.work, r.now, r.g);
    if (!clock)
        return;
    r.target = clock.at;
    for (var c = 0; c < clock.spans.length; c++)
        r.work = consume(r.work, clock.spans[c][0], clock.spans[c][1]);
}

// Clock format: « 1:30 » (min:s) or « 1:02:03 » (h:min:s).
function readColon(r) {
    if (r.target)
        return;
    var m = /(?:^|[^\d:])(\d{1,3}):(\d{2})(?::(\d{2}))?(?![\d:])/.exec(r.work);
    if (!m)
        return;
    var a = parseInt(m[1]), b = parseInt(m[2]);
    if (m[3] !== undefined) {
        r.total += a * 3600000 + b * 60000 + parseInt(m[3]) * 1000;
    } else {
        r.total += a * 60000 + b * 1000;
        if (a <= 23 && b <= 59)
            r.clockLike = { h: a, m: b, colon: true };
    }
    r.found = true;
    r.work = consume(r.work, m.index + m[0].indexOf(m[1]), m.index + m[0].length);
}

// Fractions of an hour: « 1/4 d'heure », « 3/4 of an hour », « 1/2 h ».
function readFraction(r) {
    if (r.target)
        return;
    var m;
    while ((m = r.g.fraction.exec(r.work))) {
        var a = parseInt(m[1]), b = parseInt(m[2]);
        var start = m.index + m[0].indexOf(m[1]);
        r.work = consume(r.work, start, m.index + m[0].length);
        if (a < 1 || b < 1)
            continue;
        r.total += a / b * 3600000;
        r.found = true;
    }
}

// Phrases: « demi-heure », « trois quarts d'heure », « half an hour ».
function readPhrases(r) {
    if (r.target)
        return;
    var m, start;
    while ((m = r.g.halfHour.exec(r.work))) {
        r.total += 1800000;
        r.found = true;
        start = m.index + m[0].indexOf(m[1]);
        r.work = consume(r.work, start, start + m[1].length);
    }
    while ((m = r.g.quarterHour.exec(r.work))) {
        var q = m[2] ? wordToNumber(m[2], r.g) : 1;
        if (isNaN(q))
            break;
        r.total += q * 900000;
        r.found = true;
        start = m.index + m[0].indexOf(m[1]);
        r.work = consume(r.work, start, start + m[1].length);
    }
}

// "number + unit": « 1h », « 30 min », « 2 heures et demie », with an
// implicit remainder: « 1h30 », « 2 heures 5 », « 5m30 », glued: « 1h30m20s ».
function readComponents(r) {
    if (r.target)
        return;
    var g = r.g;
    var work = r.work;
    var comps = [];
    var readComp = function (mm, start, end) {
        var value = wordToNumber(mm[1], g);
        if (isNaN(value))
            return -1;
        var u = unitMs(mm[2], g);
        var extra = mm[3] ? (g.quarterWord.test(mm[3]) ? 0.25 : 0.5) : 0;
        var ms = (value + extra) * u;
        var after = work.substring(end);
        // Implicit remainder: « 1h30 » → 30 min, « 5m30 » → 30 s.
        if (u > 1000 && !mm[3] && !g.chain.test(after)) {
            var rest = g.remainder.exec(after);
            if (rest) {
                var rv = parseInt(rest[1]);
                ms += rv * (u / 60);
                if (u === 3600000 && value % 1 === 0 && value <= 23 && rest[1].length === 2 && rv <= 59)
                    r.clockLike = { h: value, m: rv, colon: false };
                end += rest[0].length;
            } else if (mm[2] === "h" && value % 1 === 0 && value <= 23) {
                // « 8h » alone is also a time of day
                r.clockLike = { h: value, m: 0, colon: false, bare: true };
            }
        }
        comps.push({ start: start, end: end, ms: ms });
        return end;
    };
    var m;
    g.component.lastIndex = 0;
    while ((m = g.component.exec(work))) {
        var end = readComp(m, m.index + m[0].indexOf(m[1]), m.index + m[0].length);
        if (end < 0)
            continue;
        var chained;
        while ((chained = g.chain.exec(work.substring(end)))) {
            var cEnd = readComp(chained, end, end + chained[0].length);
            if (cEnd < 0)
                break;
            end = cEnd;
        }
        g.component.lastIndex = end;
    }
    for (var i = 0; i < comps.length; i++) {
        r.total += comps[i].ms;
        r.work = consume(r.work, comps[i].start, comps[i].end);
        r.found = true;
    }
    if (r.clockLike && (r.clockLike.colon ? comps.length > 0 : comps.length !== 1))
        r.clockLike = null;
}

// Bare number after "timer": minutes (« timer 5 »).
function readBareAfterKeyword(r) {
    if (r.target || r.found || !r.keyword)
        return;
    var m = /(?:^|[\s\u0000])(\d+(?:[.,]\d+)?)(?![\w:])/.exec(r.work);
    if (!m)
        return;
    r.total = parseFloat(m[1].replace(",", ".")) * 60000;
    r.found = true;
    var start = m.index + m[0].indexOf(m[1]);
    r.work = consume(r.work, start, start + m[1].length);
}

// Bare number closing a text, minutes: « pasta 12 ». Never a number alone,
// never one above MAX_BARE_MINUTES, and the text must be a label.
function readBareClosing(r) {
    if (r.target || r.found || r.keyword)
        return;
    var m = /(?:^|\s)(\d{1,3})\s*$/.exec(r.work);
    if (!m || parseInt(m[1]) < 1 || parseInt(m[1]) > MAX_BARE_MINUTES)
        return;
    var start = m.index + m[0].indexOf(m[1]);
    var rest = consume(r.work, start, start + m[1].length);
    if (/[^\s\d\u0000!-\/:-@\[-`{-~]/.test(cleanLabel(r.original, rest, r.g))) {
        r.total = parseInt(m[1]) * 60000;
        r.found = true;
        r.work = rest;
    }
}

// « dans 1 h à peu près », « about 20 min », « 20 min-ish »: a word of
// approximation touching the time read is dropped (elsewhere it is a word
// of the label: « talk about cats »).
function dropApprox(r) {
    if (!r.target && !r.found)
        return;
    var m;
    while ((m = r.g.approxAfter.exec(r.work)) || (m = r.g.approxBefore.exec(r.work))) {
        var start = m.index + m[0].indexOf(m[1]);
        r.work = consume(r.work, start, start + m[1].length);
    }
}

var STAGES = [fixUnitTypos, readContext, readKeyword, readRepeat, readClock, readColon,
              readFraction, readPhrases, readComponents, readBareAfterKeyword, readBareClosing, dropApprox];

// The candidates of a reading once every stage has run
function results(r) {
    var label = cleanLabel(r.original, r.work, r.g);
    if (r.context)
        label = label.replace(r.g.connector, "");
    label = label.substring(0, MAX_LABEL).trim();

    if (r.target)
        return withHint([{ kind: "at", at: r.target, ms: r.target - r.now, label: label }], "");
    if (!r.found)
        return noResult(r.keyword ? unknownWordHint(r.original, r.work, r.g) : "");

    var list = [];
    var total = Math.round(r.total);
    if (total >= 1000 && total <= MAX_MS)
        list.push({ kind: "duration", ms: total, label: label, count: r.count, capped: r.capped });

    // « 14h30 » or « 18:00 »: also offer the target time (first for
    // « 14h30 », which looks more like a time of day than a duration).
    // Under 6 h (« 1h30 », « 1:30 ») it can only be a duration.
    var c = r.clockLike;
    if (c) {
        var at = nextOccurrence(c.h, c.m, r.now);
        var alt = { kind: "at", at: at, ms: at - r.now, label: label };
        if (c.h >= 6) {
            // « 8h »: a duration first, unless it is too late in the day for one
            if (c.colon || (c.bare && c.h < 13))
                list.push(alt);
            else
                list.unshift(alt);
        }
    }
    return withHint(list, "");
}

// options: { keyword: the launcher's trigger was typed, grammar: another
// grammar() than every pack's (tests) }
function parse(input, now, options) {
    if (!input || tooLong(input))
        return noResult("");
    options = options || {};
    var r = newReading(input, now || Date.now(), options, options.grammar || GRAMMAR);
    for (var i = 0; i < STAGES.length; i++)
        STAGES[i](r);
    return results(r);
}


// ---------------------------------------------------------------------------
// Formatting: moved to TimeFormat.js. These re-exports keep every current
// caller (TP.formatClock…) working; new code imports TimeFormat.js directly.
// They are function declarations, not `var x = TimeFormat.x`, because
// qmllint only sees the functions of a .js import.
// ---------------------------------------------------------------------------

function pad(n) { return TimeFormat.pad(n); }
function formatClock(ms) { return TimeFormat.formatClock(ms); }
function formatHuman(ms) { return TimeFormat.formatHuman(ms); }
function formatRelative(ms) { return TimeFormat.formatRelative(ms); }
function formatTimeOfDay(epoch, use24) { return TimeFormat.formatTimeOfDay(epoch, use24); }
function isTomorrow(epoch, now) { return TimeFormat.isTomorrow(epoch, now); }
function widthTemplate(text) { return TimeFormat.widthTemplate(text); }
