.pragma library
.import "Sections.js" as Sections

// The settings search: the words typed find a setting by its label, its help
// or its synonyms (English and French), typos forgiven, ranked. Pure logic, no
// state. Tested by tests/settings-search.test.js.
//
// The matching engine is copied from Orbit's SettingsSearch.js (lung595/orbitBluetooth,
// same author, MIT) so this repo has no cross-repo dependency.
//
// find() returns [{ key, section, score, label: [[from, to)...], help: [[from, to)...], matched, text }]:
// `matched` is "label", "word" or "help", the place the best hit came from, and
// `text` is the matched text there (the whole synonym, or the words of the label
// or help that matched), so the view can show why a setting was found. An empty query and a query with no
// hit both return [] (the view says "No setting found" itself).

var MAX_RESULTS = 20;
// A longer query is cut, not refused: the first words are what the user meant
var MAX_QUERY = 64;
// Words beyond these are ignored: every one of them must match (AND)
var MAX_WORDS = 6;
// Typos are forgiven from this length on: a short word has too many neighbours
var TYPO_FROM = 5;

// Where a word was found counts for more or less
var WEIGHT = { "label": 1, "keyword": 0.8, "help": 0.5 };
var MATCHED = { "label": "label", "keyword": "word", "help": "help" };
// How the word was found: the whole word, its start, or one edit away
var EXACT = 100, PREFIX = 80, TYPO = 50;

// Accents are dropped and case folded one character at a time so every letter
// keeps its offset in the original text (the highlight needs it).
function _fold(ch) {
    const code = ch.charCodeAt(0);
    if (code < 0x80)
        return ch.toLowerCase();
    const base = ch.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    return base.length ? base[0] : "";
}

// A letter or a digit of any script; everything else separates words. Plain
// code-point ranges, because \p{...} is not available on every Qt version.
function _isWord(ch) {
    const code = ch.charCodeAt(0);
    if (code < 0x80)
        return (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
    return code >= 0xc0 && !(code >= 0x2000 && code <= 0x206f) && !(code >= 0x3000 && code <= 0x303f);
}

// The words of a text, walked letter by letter rather than through a table of
// scripts. A combining mark belongs to the letter before it: _fold drops it, so
// it never starts or splits a word. [{ t: folded word, at: offset of each letter in the text }]
function _words(text) {
    const out = [];
    let cur = null;
    for (let i = 0; i < text.length; i++) {
        const f = _fold(text[i]);
        if (f === "")
            continue;
        if (_isWord(f)) {
            if (!cur) {
                cur = { "t": "", "at": [] };
                out.push(cur);
            }
            cur.t += f;
            cur.at.push(i);
        } else {
            cur = null;
        }
    }
    return out;
}

// Is `a` one edit (a letter added, dropped, changed or two swapped) from `b`?
function _oneEdit(a, b) {
    const la = a.length, lb = b.length;
    if (Math.abs(la - lb) > 1 || a === b)
        return false;
    let i = 0;
    while (i < la && i < lb && a[i] === b[i])
        i++;
    if (la === lb) {
        if (a.slice(i + 1) === b.slice(i + 1))
            return true;
        return a[i] === b[i + 1] && a[i + 1] === b[i] && a.slice(i + 2) === b.slice(i + 2);
    }
    return la > lb ? a.slice(i + 1) === b.slice(i) : a.slice(i) === b.slice(i + 1);
}

// How a typed word matches one word of a text: { score, to } or null.
// `to` is how many letters of the word to highlight: the typed length for a
// prefix, the whole word for an exact or one-edit match. A typo is also
// forgiven in the start of a longer word, so a word still being typed
// ("notificaton") finds its target before it is finished.
function _match(q, w) {
    if (w.t === q)
        return { "score": EXACT, "to": q.length };
    if (w.t.startsWith(q))
        return { "score": PREFIX, "to": q.length };
    if (q.length >= TYPO_FROM) {
        if (_oneEdit(q, w.t))
            return { "score": TYPO, "to": w.t.length };
        if (w.t.length > q.length && _oneEdit(q, w.t.slice(0, q.length)))
            return { "score": TYPO, "to": q.length };
    }
    return null;
}

function _ranges(words, picks) {
    const spans = picks.map(p => {
        const w = words[p.word];
        return [w.at[0], w.at[p.to - 1] + 1];
    }).sort((x, y) => x[0] - y[0]);
    const out = [];
    for (const s of spans) {
        const last = out[out.length - 1];
        if (last && s[0] <= last[1])
            last[1] = Math.max(last[1], s[1]);
        else
            out.push(s);
    }
    return out;
}

// The words of every visible setting, folded once; find() takes the result so
// typing does not fold the same texts on every key
function prepare(settings) {
    const list = [];
    for (const e of Array.isArray(settings) ? settings : Sections.visibleSettings()) {
        if (!e || typeof e.key !== "string" || typeof e.label !== "string")
            continue;
        const keyTexts = (Array.isArray(e.words) ? e.words : []).filter(k => typeof k === "string");
        list.push({
            "key": e.key,
            "section": e.section,
            "label": _words(e.label),
            "help": _words(typeof e.help === "string" ? e.help : ""),
            "label_text": e.label,
            "help_text": typeof e.help === "string" ? e.help : "",
            "keyTexts": keyTexts,
            "keywords": keyTexts.map(_words)
        });
    }
    return { "list": list };
}

// How the typed word `q` is found in one setting: best score and where, plus
// the words to highlight in the label and the help
function _scan(q, item) {
    const out = { "score": 0, "where": "", "text": "", "label": [], "help": [] };
    // `source` gives the original text of the hit, cut where the word sits
    const visit = (words, kind, marks, source) => {
        words.forEach((w, i) => {
            const m = _match(q, w);
            if (!m)
                return;
            const score = m.score * WEIGHT[kind];
            if (score > out.score) {
                out.score = score;
                out.where = MATCHED[kind];
                out.text = kind === "keyword" ? source : source.slice(w.at[0], w.at[m.to - 1] + 1);
            }
            if (marks)
                marks.push({ "word": i, "to": m.to });
        });
    };
    visit(item.label, "label", out.label, item.label_text);
    item.keywords.forEach((k, i) => visit(k, "keyword", null, item.keyTexts[i]));
    visit(item.help, "help", out.help, item.help_text);
    return out;
}

// Ranked results for `query`. `source` is a settings list, what prepare() made
// of one, or nothing (the visible settings of the table).
function find(query, source) {
    if (typeof query !== "string")
        return [];
    const typed = _words(query.slice(0, MAX_QUERY)).slice(0, MAX_WORDS).map(w => w.t);
    if (typed.length === 0)
        return [];
    const prepared = source && Array.isArray(source.list) ? source : prepare(source);
    const found = [];
    prepared.list.forEach((item, order) => {
        let score = 0, best = 0, where = "", text = "";
        const label = [], help = [];
        for (const q of typed) {
            const hit = _scan(q, item);
            // Every typed word must be found somewhere (AND)
            if (hit.score === 0)
                return;
            score += hit.score;
            if (hit.score > best) {
                best = hit.score;
                where = hit.where;
                text = hit.text;
            }
            label.push(...hit.label);
            help.push(...hit.help);
        }
        found.push({
            "order": order,
            "key": item.key,
            "section": item.section,
            "score": score,
            "matched": where,
            "text": text,
            "label": _ranges(item.label, label),
            "help": _ranges(item.help, help)
        });
    });
    // Equal scores keep the order of the page, so the list never shuffles
    found.sort((a, b) => b.score - a.score || a.order - b.order);
    return found.slice(0, MAX_RESULTS).map(f => ({ "key": f.key, "section": f.section, "score": f.score, "matched": f.matched, "text": f.text, "label": f.label, "help": f.help }));
}
