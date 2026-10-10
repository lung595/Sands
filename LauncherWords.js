.pragma library

// Launcher words: the free words a user picks, in the settings, to start an
// end action from the launcher ("off 30"). Pure logic, no QML, no side
// effect. Reimplemented from the same rules as the sister plugin (no shared
// file between the two repositories), so reason codes must stay identical.
//
// An action list is [{ id, words: [string] }]. Everything is capped because
// the words come from settings and IPC (value 11).

var MAX_ACTIONS = 32;
var MAX_WORDS_PER_ACTION = 8;
var MAX_WORD_LENGTH = 24;

// Reason codes, one per way a word is refused
var EMPTY = "empty";
var TOO_LONG = "too-long";
var BAD_CHARS = "bad-chars";
var READS_AS_NUMBER = "reads-as-number";
var READS_AS_UNIT = "reads-as-unit";
var SHARED = "shared";
var TOO_MANY_WORDS = "too-many-words";
var TOO_MANY_ACTIONS = "too-many-actions";

// A word is one launcher token: letters of any alphabet, digits, - and _,
// and it must start with a letter so it can never be read as a duration.
var RE_WORD = /^\p{L}[\p{L}\p{N}_-]*$/u;
// Digits, optionally glued to a unit ("30", "30min", "1h30")
var RE_NUMBER = /^\d+(?:[a-z]+\d*)?$/;
var NUMBER_WORDS = ["zero", "un", "une", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "onze", "douze", "quinze", "vingt", "trente", "quarante", "cinquante", "soixante", "cent", "one", "two", "three", "four", "five", "seven", "eight", "nine", "ten", "eleven", "twelve", "fifteen", "twenty", "thirty", "forty", "fifty", "sixty", "hundred", "demi", "half", "quart", "quarter"];
var UNIT_WORDS = ["h", "hr", "hrs", "heure", "heures", "hour", "hours", "m", "mn", "min", "mins", "minute", "minutes", "s", "sec", "secs", "seconde", "secondes", "second", "seconds"];

// Lower-cased, trimmed, composed form of a typed word
function normalize(word) {
    return String(word === undefined || word === null ? "" : word).trim().normalize("NFC").toLowerCase();
}

// { ok, word } with the normalized word, or { ok: false, reason }
function checkWord(raw) {
    var w = normalize(raw);
    if (w === "")
        return { ok: false, reason: EMPTY };
    if (w.length > MAX_WORD_LENGTH)
        return { ok: false, reason: TOO_LONG };
    if (RE_NUMBER.test(w) || NUMBER_WORDS.indexOf(w) >= 0)
        return { ok: false, reason: READS_AS_NUMBER };
    if (UNIT_WORDS.indexOf(w) >= 0)
        return { ok: false, reason: READS_AS_UNIT };
    if (!RE_WORD.test(w))
        return { ok: false, reason: BAD_CHARS };
    return { ok: true, word: w };
}

// Checks a whole table. Returns { ok, words: { actionId: [word] }, errors:
// [{ action, word, reason }] }. Valid words are kept even when others fail,
// so a page can show what was refused and still save the rest. A word
// repeated inside one action is kept once; a word claimed by two actions is
// refused for the later one (SHARED).
function checkAll(actions) {
    var words = {};
    var errors = [];
    var owner = {};
    var list = Array.isArray(actions) ? actions : [];
    if (list.length > MAX_ACTIONS) {
        errors.push({ action: "", word: "", reason: TOO_MANY_ACTIONS });
        list = list.slice(0, MAX_ACTIONS);
    }
    list.forEach(function (a) {
        if (!a || typeof a.id !== "string")
            return;
        var kept = [];
        var raw = Array.isArray(a.words) ? a.words : [];
        raw.forEach(function (r, i) {
            if (i >= MAX_WORDS_PER_ACTION) {
                if (i === MAX_WORDS_PER_ACTION)
                    errors.push({ action: a.id, word: "", reason: TOO_MANY_WORDS });
                return;
            }
            var c = checkWord(r);
            if (!c.ok) {
                errors.push({ action: a.id, word: normalize(r).slice(0, MAX_WORD_LENGTH), reason: c.reason });
                return;
            }
            if (owner[c.word] !== undefined && owner[c.word] !== a.id) {
                errors.push({ action: a.id, word: c.word, reason: SHARED });
                return;
            }
            owner[c.word] = a.id;
            if (kept.indexOf(c.word) < 0)
                kept.push(c.word);
        });
        words[a.id] = kept;
    });
    return { ok: errors.length === 0, words: words, errors: errors };
}

// The action id a launcher word starts, or "" when it names none
function actionFor(words, raw) {
    var w = normalize(raw);
    for (var id in words) {
        if (words[id].indexOf(w) >= 0)
            return id;
    }
    return "";
}
