.pragma library
.import "TimeParser.js" as TP
.import "TimeFormat.js" as TimeFormat
.import "Timers.js" as Timers
.import "Strings.js" as Strings

// Known durations: a short built-in table (English and French, D89) plus the
// user's own entries. Pure: no QML, no clock, no side effects. `lookup`
// speaks seconds; `suggest`, for the launcher, speaks milliseconds.

var MAX_ENTRIES = 50;
var MAX_NAME = 40;
var MIN_SECONDS = 5;
var MAX_SECONDS = 24 * 3600;
var MAX_QUERY = 80;

// [seconds, names...]; every name is looked up through key(), so accents
// and case do not matter here either.
var BUILT_IN = [
    [180, "green tea", "thé vert"],
    [240, "black tea", "thé noir"],
    [300, "tea", "thé", "herbal tea", "tisane", "infusion"],
    [240, "french press", "cafetière à piston"],
    [360, "soft-boiled egg", "œuf à la coque"],
    [420, "medium egg", "œuf mollet"],
    [600, "hard-boiled egg", "œuf dur"],
    [600, "pasta", "pâtes"],
    [720, "rice", "riz"],
    [1200, "brown rice", "riz complet"],
    [900, "quinoa"],
    [1200, "power nap", "sieste"],
    [2400, "pizza"]
];

// Lowercase, no accents, ligatures spelled out, punctuation folded to single
// spaces, so "Thé-vert" and "the  vert" are the same key. English and French
// only (D89): any other script folds to nothing, so such a name has an empty
// key and is ignored. Over-long text is refused, not truncated.
function key(text) {
    if (typeof text !== "string" || text.length > MAX_QUERY)
        return "";
    var s = text.toLowerCase().replace(/œ/g, "oe").replace(/æ/g, "ae");
    return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
}

// key() with each word made singular, so « pâte » finds « pâtes » and
// « oeufs durs » finds « œuf dur »: a final s goes (not after another s, not
// on words of three letters or less), « -aux / -eux / -oux » lose their x.
function matchKey(text) {
    return key(text).split(" ").map(function (w) {
        if (w.length > 3 && /[^s]s$/.test(w))
            return w.slice(0, -1);
        return /[aeo]ux$/.test(w) ? w.slice(0, -1) : w;
    }).join(" ");
}

// The valid, capped entries of `raw` ([{name, seconds}, …]) as a map
// key → seconds. Malformed ones are skipped; for a repeated name the last wins.
function userMap(raw) {
    var map = {};
    if (!Array.isArray(raw))
        return map;
    var n = Math.min(raw.length, MAX_ENTRIES);
    for (var i = 0; i < n; i++) {
        var e = raw[i];
        if (!e || typeof e.name !== "string" || typeof e.seconds !== "number")
            continue;
        var k = matchKey(e.name);
        if (k === "" || e.name.length > MAX_NAME || !isFinite(e.seconds))
            continue;
        if (e.seconds < MIN_SECONDS || e.seconds > MAX_SECONDS)
            continue;
        map[k] = Math.round(e.seconds);
    }
    return map;
}

// Seconds for `name`: the user's entry first, then the built-in table, else null.
function lookup(name, userEntries) {
    var k = matchKey(name);
    if (k === "")
        return null;
    var user = userMap(userEntries);
    if (Object.prototype.hasOwnProperty.call(user, k))
        return user[k];
    for (var i = 0; i < BUILT_IN.length; i++)
        for (var j = 1; j < BUILT_IN[i].length; j++)
            if (matchKey(BUILT_IN[i][j]) === k)
                return BUILT_IN[i][0];
    return null;
}

// A history record that starts this soon (ms) after the end of an earlier one
// with the same name is taken for a snooze or a repeat (the daemon writes one
// more record each time a snoozed timer rings again, holding only the snooze
// length), not for a duration the user gave
var CHAIN_GAP_MS = 10 * 60 * 1000;

// The latest duration (ms) the user gave to a timer named like `k` (a
// matchKey); null when none. The recents ({ ms, label, last },
// Timers.remember) hold the durations the user typed, so they come first;
// the history records ({ name, start, end }, History.js) only count for a
// name the recents lack, the latest start winning, snooze chains skipped.
// Durations outside 1 s .. TP.MAX_MS are skipped.
function lastOwn(k, recents, history) {
    var best = null, bestAt = -Infinity;
    function offer(label, ms, at) {
        if (typeof label !== "string" || typeof ms !== "number" || !isFinite(ms) || ms < 1000 || ms > TP.MAX_MS)
            return;
        var t = typeof at === "number" && isFinite(at) ? at : -Infinity;
        if ((best === null || t > bestAt) && matchKey(label) === k) {
            best = Math.round(ms);
            bestAt = t;
        }
    }
    if (Array.isArray(recents))
        for (var i = 0; i < recents.length; i++)
            if (recents[i])
                offer(recents[i].label, recents[i].ms, recents[i].last);
    if (best !== null)
        return best;
    var records = history && Array.isArray(history.records) ? history.records : Array.isArray(history) ? history : [];
    var ends = [];
    for (var j = 0; j < records.length; j++) {
        var r = records[j];
        if (r && typeof r.name === "string" && typeof r.start === "number" && typeof r.end === "number" && isFinite(r.start) && isFinite(r.end) && matchKey(r.name) === k)
            ends.push(r.end);
    }
    for (var n = 0; n < records.length; n++) {
        var h = records[n];
        if (!h || typeof h.start !== "number" || typeof h.end !== "number")
            continue;
        var chained = false;
        for (var e = 0; e < ends.length && !chained; e++)
            chained = ends[e] <= h.start && h.start - ends[e] <= CHAIN_GAP_MS;
        if (!chained)
            offer(h.name, h.end - h.start, h.start);
    }
    return best;
}

// The language of a launcher trigger word (« minuteur » → "fr"), "" when
// both packs have it (« timer ») or none does
var KEYWORD_RES = null;
function keywordLang(work) {
    if (KEYWORD_RES === null)
        KEYWORD_RES = TP.PACKS.map(function (p) {
            return { lang: p.NAME, re: new RegExp("^\\s*(?:" + p.KEYWORDS.join("|") + ")(?![a-z])") };
        });
    var found = "";
    for (var i = 0; i < KEYWORD_RES.length; i++) {
        if (!KEYWORD_RES[i].re.test(work))
            continue;
        if (found !== "")
            return "";
        found = KEYWORD_RES[i].lang;
    }
    return found;
}

// What the launcher proposes for a name typed without any number:
// « timer pâtes » → { ms: 600000, source: "table", name: "pâtes",
// text: "Pâtes — 10 min (durée habituelle)", icon: "timer" }.
//   text     the raw query, with or without the trigger word (« timer »,
//            « minuteur »…); emoji, case and accents do not matter
//   options  { recents, history, entries, lang }: the daemon's recents and
//            history, the user's own entries (`lookup`), and "fr" / "en"
//            (or a locale such as "fr_FR"); without it the trigger word's
//            language, else English
// source "mine": the user's latest typed duration for that name (recents,
// else history), else one of their entries; "table": the built-in table. `name`
// is the label to start the timer with; `icon` a Material Symbols name.
// null when the name is unknown, empty or too long.
function suggest(text, options) {
    if (typeof text !== "string" || text.length > MAX_QUERY)
        return null;
    var o = options || {};
    var work = TP.normalize(text);
    var m = TP.GRAMMAR.keyword.exec(work);
    var trigger = m ? keywordLang(work) : "";
    var name = Timers.stripEmoji(m ? text.substring(m[0].length) : text, 0).replace(/^[\s:,;.-]+|[\s:,;.!?-]+$/g, "");
    var k = matchKey(name);
    if (k === "")
        return null;
    var ms = lastOwn(k, o.recents, o.history), source = "mine";
    if (ms === null) {
        var user = userMap(o.entries);
        if (Object.prototype.hasOwnProperty.call(user, k))
            ms = user[k] * 1000;
        else {
            var s = lookup(name);
            if (s === null)
                return null;
            ms = s * 1000;
            source = "table";
        }
    }
    var lang = typeof o.lang === "string" && o.lang !== "" ? o.lang : (trigger || "en");
    var shown = name.charAt(0).toUpperCase() + name.slice(1);
    return {
        ms: ms,
        source: source,
        name: name,
        icon: source === "mine" ? "history" : "timer",
        text: Strings.tr("known.usual", lang, shown, TimeFormat.formatHuman(ms))
    };
}
