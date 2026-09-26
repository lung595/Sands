.pragma library

// Free-form input parser (French / English) for starting a timer.
//
// parse("timer 1h30 pâtes", now, { keyword: false }) returns a list of
// candidates, most likely first:
//   [{ kind: "duration", ms: 5400000, label: "pâtes" }]
//   [{ kind: "at", at: <epoch ms>, ms: <ms until that time>, label: "" }]
// An empty list means "this is not a timer": the launcher then stays
// silent for every other search.

var MAX_MS = 100 * 3600 * 1000;

var KEYWORDS = "timer|minuteur|minuterie|countdown|compte a rebours|chrono|alarme|alarm|rappel|reminder|reveil";

var WORD_VALUES = {
    "zero": 0, "un": 1, "une": 1, "a": 1, "an": 1, "one": 1,
    "deux": 2, "two": 2, "trois": 3, "three": 3, "quatre": 4, "four": 4,
    "cinq": 5, "five": 5, "six": 6, "sept": 7, "seven": 7, "huit": 8, "eight": 8,
    "neuf": 9, "nine": 9, "dix": 10, "ten": 10, "onze": 11, "eleven": 11,
    "douze": 12, "twelve": 12, "treize": 13, "thirteen": 13, "quatorze": 14, "fourteen": 14,
    "quinze": 15, "fifteen": 15, "seize": 16, "sixteen": 16,
    "seventeen": 17, "eighteen": 18, "nineteen": 19,
    "vingt": 20, "twenty": 20, "trente": 30, "thirty": 30, "quarante": 40, "forty": 40,
    "cinquante": 50, "fifty": 50, "soixante": 60, "sixty": 60
};

var TENS = "vingt|trente|quarante|cinquante|soixante|twenty|thirty|forty|fifty|sixty";
var UNITS_W = "une|un|deux|trois|quatre|cinq|six|sept|huit|neuf|one|two|three|four|five|seven|eight|nine";
var SINGLE = "zero|onze|douze|treize|quatorze|quinze|seize|seventeen|eighteen|nineteen|eleven|twelve|thirteen|fourteen|fifteen|sixteen|dix|ten|" + UNITS_W + "|six|an|a";
var WORDNUM = "(?:(?:" + TENS + ")(?:[- ](?:et[- ])?(?:" + UNITS_W + "|six))?|dix[- ](?:sept|huit|neuf)|" + SINGLE + ")";
var NUM = "(\\d+(?:[.,]\\d+)?|" + WORDNUM + ")";

var U_HOUR = "heures?|hours?|hrs?|h";
var U_MIN = "minutes?|mins?|mn|m";
var U_SEC = "secondes?|seconds?|secs?|s";
var UNIT = "(" + U_HOUR + "|" + U_MIN + "|" + U_SEC + ")";
var HALF = "(?:\\s*(?:et|and)\\s*(demie?|quart|a half|half|a quarter|quarter))?";

var RE_HOUR = new RegExp("^(?:" + U_HOUR + ")$");
var RE_MIN = new RegExp("^(?:" + U_MIN + ")$");

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

function wordToNumber(w) {
    w = w.trim();
    if (/^\d/.test(w))
        return parseFloat(w.replace(",", "."));
    if (WORD_VALUES[w] !== undefined)
        return WORD_VALUES[w];
    var parts = w.split(/[- ]+/).filter(function (p) {
        return p !== "et";
    });
    if (parts.length === 2 && parts[0] === "dix")
        return 10 + (WORD_VALUES[parts[1]] || NaN);
    var total = 0;
    for (var i = 0; i < parts.length; i++) {
        if (WORD_VALUES[parts[i]] === undefined)
            return NaN;
        total += WORD_VALUES[parts[i]];
    }
    return total;
}

function unitMs(u) {
    if (RE_HOUR.test(u))
        return 3600000;
    if (RE_MIN.test(u))
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

function cleanLabel(original, work) {
    var kept = "";
    for (var i = 0; i < original.length; i++)
        kept += work.charAt(i) === "\u0000" ? " " : original.charAt(i);
    kept = kept.replace(/\s+/g, " ").trim();
    var head = /^(?:(?:pour|for|de|dans|in|et|and|a|à|at|le|la|les|the)(?=\s|$)|d'|:|-|–|—|,|\.)\s*/i;
    var tail = /\s*(?:(?:^|\s)(?:pour|for|de|dans|in|et|and|a|à|at)|d'|:|-|–|—|,)$/i;
    var prev;
    do {
        prev = kept;
        kept = kept.replace(head, "").replace(tail, "").trim();
    } while (kept !== prev);
    return kept;
}

function parse(input, now, options) {
    if (!input)
        return [];
    now = now || Date.now();
    options = options || {};
    var original = String(input);
    var work = normalize(original);
    var hasKeyword = !!options.keyword;
    var m;

    var kw = new RegExp("^\\s*(?:" + KEYWORDS + ")(?![a-z])").exec(work);
    if (kw) {
        hasKeyword = true;
        work = consume(work, 0, kw[0].length);
    }

    var total = 0;
    var found = false;
    var target = null;
    var clockLike = null;

    // 1. Explicit target time: « à 18h », « à 18:30 », « at 6pm », « vers midi ».
    var atRe = /(?:^|[\s\u0000])(?:a|at|vers|until|jusqu'a|@)\s*(?:(midi|noon)|(minuit|midnight)|(\d{1,2})(?:\s*(h)\s*(\d{2})?|:(\d{2}))?\s*(am|pm)?)(?![\w:])/;
    m = atRe.exec(work);
    if (m && (m[1] || m[2] || m[4] || m[6] !== undefined || m[7])) {
        var hh = 0, mm = 0;
        if (m[1]) {
            hh = 12;
        } else if (!m[2]) {
            hh = parseInt(m[3]);
            mm = parseInt(m[5] || m[6] || "0");
            if (m[7] === "pm" && hh < 12)
                hh += 12;
            if (m[7] === "am" && hh === 12)
                hh = 0;
        }
        if (hh <= 23 && mm <= 59) {
            target = nextOccurrence(hh, mm, now);
            work = consume(work, m.index, m.index + m[0].length);
        }
    }

    // 1b. « 7am », « 6:30 pm »: a time with am/pm is always a moment.
    if (!target) {
        m = /(?:^|[\s\u0000])(\d{1,2})(?::(\d{2}))?\s*(am|pm)(?![\w])/.exec(work);
        if (m) {
            let h12 = parseInt(m[1]);
            const mn = parseInt(m[2] || "0");
            if (h12 >= 1 && h12 <= 12 && mn <= 59) {
                if (m[3] === "pm" && h12 < 12)
                    h12 += 12;
                if (m[3] === "am" && h12 === 12)
                    h12 = 0;
                target = nextOccurrence(h12, mn, now);
                work = consume(work, m.index, m.index + m[0].length);
            }
        }
    }

    if (!target) {
        // 2. Clock format: « 1:30 » (min:s) or « 1:02:03 » (h:min:s).
        m = /(?:^|[^\d:])(\d{1,3}):(\d{2})(?::(\d{2}))?(?![\d:])/.exec(work);
        if (m) {
            var a = parseInt(m[1]), b = parseInt(m[2]);
            if (m[3] !== undefined) {
                total += a * 3600000 + b * 60000 + parseInt(m[3]) * 1000;
            } else {
                total += a * 60000 + b * 1000;
                if (a <= 23 && b <= 59)
                    clockLike = { h: a, m: b, colon: true };
            }
            found = true;
            var cs = m.index + m[0].indexOf(m[1]);
            work = consume(work, cs, m.index + m[0].length);
        }

        // 3. Phrases: « demi-heure », « trois quarts d'heure », « half an hour ».
        var halfRe = /(?:^|[^a-z])((?:(?:une|a|an|1)\s+)?(?:demi[- ]?heure|half[- ](?:an[- ])?hour))(?![a-z])/;
        while ((m = halfRe.exec(work))) {
            total += 1800000;
            found = true;
            var hs = m.index + m[0].indexOf(m[1]);
            work = consume(work, hs, hs + m[1].length);
        }
        var quarterRe = new RegExp("(?:^|[^a-z0-9])((?:" + NUM + "\\s+)?(?:quarts?\\s+d'?\\s*heure|quarters?(?:\\s+of)?(?:\\s+an)?[- ]hour))(?![a-z])");
        while ((m = quarterRe.exec(work))) {
            var q = m[2] ? wordToNumber(m[2]) : 1;
            if (isNaN(q))
                break;
            total += q * 900000;
            found = true;
            var qs = m.index + m[0].indexOf(m[1]);
            work = consume(work, qs, qs + m[1].length);
        }

        // 4. "number + unit": « 1h », « 30 min », « 2 heures et demie »,
        //    with an implicit remainder: « 1h30 », « 2 heures 5 », « 5m30 ».
        var compRe = new RegExp("(?:^|[^a-z0-9.,'])" + NUM + "\\s*" + UNIT + "(?![a-z])" + HALF, "g");
        var chainRe = new RegExp("^\\s*" + NUM + "\\s*" + UNIT + "(?![a-z])" + HALF);
        // Implicit remainder, unless it carries its own unit (« 1h 30min » is read separately).
        var restRe = new RegExp("^\\s*(\\d{1,2})(?![\\d.,:]|\\s*" + UNIT + "(?![a-z]))");
        var comps = [];
        var readComp = function (mm, start, end) {
            var value = wordToNumber(mm[1]);
            if (isNaN(value))
                return -1;
            var u = unitMs(mm[2]);
            var extra = mm[3] ? (/quart|quarter/.test(mm[3]) ? 0.25 : 0.5) : 0;
            var ms = (value + extra) * u;
            var after = work.substring(end);
            // Implicit remainder: « 1h30 » → 30 min, « 5m30 » → 30 s.
            if (u > 1000 && !mm[3] && !chainRe.test(after)) {
                var rest = restRe.exec(after);
                if (rest) {
                    var rv = parseInt(rest[1]);
                    ms += rv * (u / 60);
                    if (u === 3600000 && value % 1 === 0 && value <= 23 && rest[1].length === 2 && rv <= 59)
                        clockLike = { h: value, m: rv, colon: false };
                    end += rest[0].length;
                }
            }
            comps.push({ start: start, end: end, ms: ms });
            return end;
        };
        while ((m = compRe.exec(work))) {
            var end = readComp(m, m.index + m[0].indexOf(m[1]), m.index + m[0].length);
            if (end < 0)
                continue;
            // Glued components: « 1h30m20s ».
            var chained;
            while ((chained = chainRe.exec(work.substring(end)))) {
                var cEnd = readComp(chained, end, end + chained[0].length);
                if (cEnd < 0)
                    break;
                end = cEnd;
            }
            compRe.lastIndex = end;
        }
        for (var i = 0; i < comps.length; i++) {
            total += comps[i].ms;
            work = consume(work, comps[i].start, comps[i].end);
            found = true;
        }
        if (clockLike && !clockLike.colon && comps.length !== 1)
            clockLike = null;
        if (clockLike && clockLike.colon && comps.length > 0)
            clockLike = null;

        // 5. Bare number after "timer": minutes (« timer 5 »).
        if (!found && hasKeyword) {
            m = /(?:^|[\s\u0000])(\d+(?:[.,]\d+)?)(?![\w:])/.exec(work);
            if (m) {
                total = parseFloat(m[1].replace(",", ".")) * 60000;
                found = true;
                var s0 = m.index + m[0].indexOf(m[1]);
                work = consume(work, s0, s0 + m[1].length);
            }
        }
    }

    var label = cleanLabel(original, work);

    if (target)
        return [{ kind: "at", at: target, ms: target - now, label: label }];
    if (!found)
        return [];

    var results = [];
    total = Math.round(total);
    if (total >= 1000 && total <= MAX_MS)
        results.push({ kind: "duration", ms: total, label: label });

    // « 14h30 » or « 18:00 »: also offer the target time (first for
    // « 14h30 », which looks more like a time of day than a duration).
    // Under 6 h (« 1h30 », « 1:30 ») it can only be a duration.
    if (clockLike) {
        var at = nextOccurrence(clockLike.h, clockLike.m, now);
        var alt = { kind: "at", at: at, ms: at - now, label: label };
        if (clockLike.h >= 6) {
            if (clockLike.colon)
                results.push(alt);
            else
                results.unshift(alt);
        }
    }
    return results;
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

function pad(n) {
    return n < 10 ? "0" + n : "" + n;
}

// Countdown, rounded up to the next second: 20:00 at the start, 0:00
// exactly when it rings. Negative = time elapsed since the end (« −0:12 »).
function formatClock(ms) {
    var neg = ms < 0;
    var s = neg ? Math.floor(-ms / 1000) : Math.ceil(ms / 1000);
    var h = Math.floor(s / 3600);
    var mn = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var txt = h > 0 ? h + ":" + pad(mn) + ":" + pad(sec) : mn + ":" + pad(sec);
    return (neg && s > 0 ? "−" : "") + txt;
}

// Readable duration: « 1 h 30 », « 20 min », « 1 min 30 s », « 45 s ».
function formatHuman(ms) {
    var s = Math.round(ms / 1000);
    var h = Math.floor(s / 3600);
    var mn = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    if (h > 0)
        return mn > 0 ? h + " h " + pad(mn) : h + " h";
    if (mn > 0)
        return sec > 0 ? mn + " min " + sec + " s" : mn + " min";
    return sec + " s";
}

// Duration rounded to the minute, for « dans 2 h 16 » ("in 2 h 16").
function formatRelative(ms) {
    var mnTotal = Math.round(ms / 60000);
    if (mnTotal < 1)
        return formatHuman(ms);
    var h = Math.floor(mnTotal / 60);
    var mn = mnTotal % 60;
    if (h > 0)
        return mn > 0 ? h + " h " + pad(mn) : h + " h";
    return mn + " min";
}

function formatTimeOfDay(epoch, use24) {
    var d = new Date(epoch);
    var h = d.getHours();
    var mn = pad(d.getMinutes());
    if (use24 === false) {
        var h12 = h % 12 === 0 ? 12 : h % 12;
        return h12 + ":" + mn + (h >= 12 ? " PM" : " AM");
    }
    return pad(h) + ":" + mn;
}

function isTomorrow(epoch, now) {
    return new Date(epoch).getDate() !== new Date(now || Date.now()).getDate();
}

// Fixed-width template (digits replaced by 0) so the pill does not move
// every second.
function widthTemplate(text) {
    return text.replace(/\d/g, "0");
}
