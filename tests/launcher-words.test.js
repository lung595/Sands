// LauncherWords.js tests — run with: gjs tests/launcher-words.test.js
// Every validation rule and every reason code of the free launcher words.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const W = load("LauncherWords.js");

// Accepted words, normalized
eq(W.checkWord("off"), { ok: true, word: "off" }, "plain word");
eq(W.checkWord("  Dodo "), { ok: true, word: "dodo" }, "trimmed and lower-cased");
eq(W.checkWord("zzz"), { ok: true, word: "zzz" }, "meaningless word");
eq(W.checkWord("éteins"), { ok: true, word: "éteins" }, "accented word");
eq(W.checkWord("bye-bye_1"), { ok: true, word: "bye-bye_1" }, "dash, underscore, digit inside");

// One reason code per refusal
eq(W.checkWord("").reason, "empty", "empty");
eq(W.checkWord("   ").reason, "empty", "blank");
eq(W.checkWord(undefined).reason, "empty", "undefined");
eq(W.checkWord("a".repeat(25)).reason, "too-long", "too long");
eq(W.checkWord("a".repeat(24)).ok, true, "at the cap");
eq(W.checkWord("30").reason, "reads-as-number", "digits");
eq(W.checkWord("30min").reason, "reads-as-number", "digits with unit");
eq(W.checkWord("1h30").reason, "reads-as-number", "hour and minutes glued");
eq(W.checkWord("cinq").reason, "reads-as-number", "number word fr");
eq(W.checkWord("Twenty").reason, "reads-as-number", "number word en");
eq(W.checkWord("min").reason, "reads-as-unit", "unit short");
eq(W.checkWord("heures").reason, "reads-as-unit", "unit word fr");
eq(W.checkWord("h").reason, "reads-as-unit", "unit letter");
eq(W.checkWord("a b").reason, "bad-chars", "space");
eq(W.checkWord("rm;ls").reason, "bad-chars", "punctuation");
eq(W.checkWord("-x").reason, "bad-chars", "starts with a dash");
eq(W.checkWord("a\nb").reason, "bad-chars", "control character");

// Whole table
let r = W.checkAll([{ id: "a", words: ["off", "Off", "bye"] }, { id: "b", words: ["zzz"] }]);
eq(r, { ok: true, words: { a: ["off", "bye"], b: ["zzz"] }, errors: [] }, "valid table, duplicate inside one action kept once");
r = W.checkAll([{ id: "a", words: ["off"] }, { id: "b", words: ["OFF", "zzz"] }]);
eq(r.ok, false, "shared word fails the table");
eq(r.errors, [{ action: "b", word: "off", reason: "shared" }], "shared word reason");
eq(r.words, { a: ["off"], b: ["zzz"] }, "other words are kept");
r = W.checkAll([{ id: "a", words: ["12", "ok"] }]);
eq(r.errors, [{ action: "a", word: "12", reason: "reads-as-number" }], "refused word reported with its action");
eq(r.words.a, ["ok"], "valid word survives");
r = W.checkAll([{ id: "a", words: "abcdefghij".split("").map(c => "w" + c) }]);
eq(r.words.a.length, 8, "words per action capped");
eq(r.errors.map(e => e.reason), ["too-many-words"], "cap reason");
r = W.checkAll(Array.from({ length: 33 }, (_, i) => ({ id: "x" + i, words: [] })));
eq(Object.keys(r.words).length, 32, "actions capped");
eq(r.errors[0].reason, "too-many-actions", "actions cap reason");
eq(W.checkAll(null), { ok: true, words: {}, errors: [] }, "garbage input");
eq(W.checkAll([null, { id: 3 }, { id: "a", words: 5 }]).words, { a: [] }, "malformed entries ignored");

// Lookup
const t = { a: ["off"], b: ["zzz", "dodo"] };
eq(W.actionFor(t, " DODO"), "b", "lookup normalizes");
eq(W.actionFor(t, "nope"), "", "unknown word names no action");
eq(W.actionFor(t, ""), "", "empty word names no action");

// Every word the parser reads as a number or a unit is refused (one rule)
const TP = load("TimeParser.js");
Object.keys(TP.WORD_VALUES).forEach(k => eq(W.checkWord(k).reason, "reads-as-number", "parser number word " + k));
["demi", "demie", "half", "quart", "quarter"].forEach(k => eq(W.checkWord(k).reason, "reads-as-number", "half word " + k));
["h", "hr", "hrs", "heure", "heures", "hour", "hours", "m", "mn", "min", "mins", "minute", "minutes", "s", "sec", "secs", "seconde", "secondes", "second", "seconds"]
    .forEach(k => eq(W.checkWord(k).reason, "reads-as-unit", "parser unit " + k));
eq(W.checkAll([{ id: "a", words: ["constructor"] }]).words.a, ["constructor"], "object property names are plain words");
eq(W.checkAll([{ id: "a", words: ["toString"] }, { id: "b", words: ["tostring"] }]).errors[0].reason, "shared", "shared still caught");
["dix-sept", "vingt-cinq", "twenty-five", "quatre-vingt", "vingt-et-un"].forEach(k => eq(W.checkWord(k).reason, "reads-as-number", "compound number " + k));
eq(W.checkWord("bye-bye").ok, true, "bye-bye stays a word");
eq(W.checkWord("-").reason, "bad-chars", "lone dash is bad chars");
eq(W.checkWord(" ".repeat(100) + "off").word, "off", "leading spaces do not hide a word");
eq(W.checkWord("x".repeat(100000)).reason, "too-long", "huge input");
done();
