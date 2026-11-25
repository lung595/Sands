// Known durations test — run with: gjs tests/known-durations.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq, done, load } = imports.harness;
const K = load("KnownDurations.js");
const H = load("components/daemon/History.js");
const L = load("components/daemon/Lifecycle.js");

// Built-in table, both languages
eq(K.lookup("green tea"), 180, "en green tea");
eq(K.lookup("thé vert"), 180, "fr thé vert");
eq(K.lookup("soft-boiled egg"), 360, "en soft-boiled egg");
eq(K.lookup("œuf à la coque"), 360, "fr oeuf à la coque");
eq(K.lookup("rice"), 720, "en rice");
eq(K.lookup("riz"), 720, "fr riz");

// Case, accents, punctuation
eq(K.lookup("GREEN  Tea"), 180, "case and spaces");
eq(K.lookup("THE VERT"), 180, "accents ignored");
eq(K.lookup("soft boiled egg"), 360, "hyphen folded");

// Unknown or bad input
eq(K.lookup("unicorn"), null, "unknown");
eq(K.lookup(""), null, "empty");
eq(K.lookup(null), null, "null");
eq(K.lookup(42), null, "number");
eq(K.lookup("x".repeat(5000)), null, "huge query");
eq(K.lookup("green tea" + " ".repeat(100) + "junk"), null, "over-long query refused, not truncated");
eq(K.lookup("ＧＲＥＥＮ tea"), 300, "non-Latin letters fold away (English and French only)");
eq(K.lookup("ラーメン", [{ name: "ラーメン", seconds: 210 }]), null, "non-Latin user entry ignored");

// User entries: new name, override, accents
eq(K.lookup("Ramen", [{ name: "ramen", seconds: 210 }]), 210, "user entry");
eq(K.lookup("green tea", [{ name: "Green Tea", seconds: 150 }]), 150, "user wins");
eq(K.lookup("thé vert", [{ name: "the vert", seconds: 150 }]), 150, "user override accent-insensitive");
eq(K.lookup("green tea", [{ name: "x", seconds: 9 }]), 180, "other entry leaves built-in");
eq(K.lookup("a", [{ name: "a", seconds: 10 }, { name: "a", seconds: 20 }]), 20, "last duplicate wins");

// Caps
eq(K.lookup("long", [{ name: "x".repeat(41), seconds: 60 }]), null, "name too long");
eq(K.lookup("five", [{ name: "five", seconds: 5 }]), 5, "min duration ok");
eq(K.lookup("frac", [{ name: "frac", seconds: 90.4 }]), 90, "fractional rounded");
eq(K.lookup("tiny", [{ name: "tiny", seconds: 4 }]), null, "duration too short");
eq(K.lookup("huge", [{ name: "huge", seconds: 86401 }]), null, "duration too long");
eq(K.lookup("edge", [{ name: "edge", seconds: 86400 }]), 86400, "max duration ok");
const many = Array.from({ length: 50 }, (_, i) => ({ name: "item" + i, seconds: 60 }));
eq(K.lookup("item49", many), 60, "last entry within count cap");
const over = Array.from({ length: 50 }, (_, i) => ({ name: "pad" + i, seconds: 60 })).concat([{ name: "late", seconds: 60 }]);
eq(K.lookup("late", over), null, "entry beyond count cap ignored");

// Malformed entries never throw
for (const bad of [null, undefined, "str", 5, {}, [null], [undefined], [{}], [{ name: 1, seconds: 60 }], [{ name: "n", seconds: "60" }], [{ name: "n", seconds: NaN }], [{ name: "n", seconds: Infinity }], [{ name: "  ", seconds: 60 }]])
    eq(K.lookup("green tea", bad), 180, "malformed " + JSON.stringify(bad));
// Plural and singular fold to the same key
eq(K.lookup("pâte"), 600, "singular finds the plural entry");
eq(K.lookup("oeufs durs"), 600, "plural finds the singular entry");
eq(K.lookup("green teas"), 180, "english plural");
eq(K.matchKey("gâteaux"), "gateau", "-aux plural");
eq(K.matchKey("glass"), "glass", "double s kept");
eq(K.matchKey("riz"), "riz", "short word kept");

// suggest: the launcher line for a name without a number
const S = (text, o) => K.suggest(text, o);
eq(S("timer pâtes"), { ms: 600000, source: "table", name: "pâtes", icon: "timer", text: "Pâtes \u2014 10 min (usual time)" }, "table, English by default");
eq(S("timer pâtes", { lang: "fr" }).text, "Pâtes \u2014 10 min (durée habituelle)", "French text");
eq(S("timer pasta", { lang: "en" }).text, "Pasta \u2014 10 min (usual time)", "English text");
eq(S("timer pasta", { lang: "fr_FR" }).text, "Pasta \u2014 10 min (durée habituelle)", "locale name accepted");
eq(S("minuteur pâtes").text, "Pâtes \u2014 10 min (durée habituelle)", "French trigger gives French");
eq(S("countdown pasta").text, "Pasta \u2014 10 min (usual time)", "English trigger gives English");
eq(S("minuteur pâtes", { lang: "en" }).text, "Pâtes \u2014 10 min (usual time)", "explicit lang wins over the trigger");
eq(S("pâtes").ms, 600000, "without trigger word");
eq(S("TIMER PÂTES").ms, 600000, "case");
eq(S("timer PATES").name, "PATES", "accents ignored, name kept as typed");
eq(S("timer 🍝 pâtes"), S("timer pâtes"), "emoji stripped");
eq(S("timer pâtes 🍝🍝").name, "pâtes", "trailing emoji stripped");
eq(S("timer pâte").ms, 600000, "singular");
eq(S("timer oeufs durs").text, "Oeufs durs \u2014 10 min (usual time)", "plural");
eq(S("timer thé vert", { lang: "fr" }).text, "Thé vert \u2014 3 min (durée habituelle)", "minutes under ten");
eq(S("timer riz complet").text, "Riz complet \u2014 20 min (usual time)", "two words");

// The user's own durations come first
const t0 = 1700000000000;
const recents = [{ ms: 480000, label: "Pâtes", uses: 3, last: t0 }];
eq(S("timer pâtes", { recents: recents, lang: "fr" }), { ms: 480000, source: "mine", name: "pâtes", icon: "history", text: "Pâtes \u2014 8 min (durée habituelle)" }, "recents before the table");
eq(S("timer ramen", { recents: [{ ms: 210000, label: "ramen", uses: 1, last: t0 }] }).text, "Ramen \u2014 3 min 30 s (usual time)", "a name the table lacks");
eq(S("timer 🍜 Ramens", { recents: [{ ms: 210000, label: "Ramen 🍜", last: t0 }] }).ms, 210000, "emoji and plural on both sides");
const history = { records: [{ name: "pâtes", start: t0 + 1000, end: t0 + 1000 + 720000 }] };
eq(S("timer pâtes", { history: history }).ms, 720000, "history alone");
eq(S("timer pâtes", { history: history.records }).ms, 720000, "history as a bare record list");
eq(S("timer pâtes", { recents: recents, history: history }).ms, 480000, "recents before a later history record");
eq(S("timer pâtes", { recents: [{ ms: 540000, label: "pates", last: t0 + 5000 }], history: history }).ms, 540000, "recents before history");
eq(S("timer pâtes", { recents: [{ ms: 300000, label: "riz", last: t0 }], history: history }).ms, 720000, "history for a name the recents lack");
eq(S("timer pâtes", { history: [{ name: "pâtes", start: t0, end: t0 + 300000 }, { name: "Pates", start: t0 + 86400000, end: t0 + 86400000 + 540000 }] }).ms, 540000, "latest history record");

// A snooze writes one more record holding only the snooze length: the typed
// duration still wins (the daemon's real path: Lifecycle.adjust + History)
(function () {
    const tm = L.make(1, 600000, "pâtes", "duration", t0, t0, 60);
    let h = H.add(H.parse(""), "pâtes", H.fromTimer("pâtes", t0 + 600000, tm.total).start, t0 + 600000, t0 + 600000);
    tm.state = "ringing";
    L.adjust(tm, t0 + 630000, 300000, 100 * 3600000);
    const r2 = H.fromTimer("pâtes", t0 + 930000, tm.total);
    h = H.add(h, r2.name, r2.start, r2.end, t0 + 930000);
    eq(h.records.length, 2, "snooze: two records");
    eq(S("timer pâtes", { recents: [{ ms: 600000, label: "pâtes", uses: 1, last: t0 }], history: h }).ms, 600000, "snooze: recents win");
    eq(S("timer pâtes", { history: h }).ms, 600000, "snooze: chained record skipped");
    eq(S("timer pâtes", { history: h.records.concat([{ name: "riz", start: t0 + 600000, end: t0 + 900000 }]) }).ms, 600000, "snooze: another name never chains");
})();
eq(S("timer pâtes", { history: [{ name: "pâtes", start: t0, end: t0 + 600000 }, { name: "pâtes", start: t0 + 600000 + 11 * 60000, end: t0 + 600000 + 11 * 60000 + 480000 }] }).ms, 480000, "a later run past the chain gap counts");
eq(S("timer pâtes", { recents: [{ ms: 300000, label: "pates", last: t0 }, { ms: 420000, label: "PÂTES", last: t0 + 9 }] }).ms, 420000, "latest of several recents");
eq(S("timer pâtes", { recents: [{ ms: 300000, label: "riz", last: t0 }] }).source, "table", "other names ignored");
eq(S("timer pâtes", { entries: [{ name: "pâtes", seconds: 660 }] }).ms, 660000, "user entry before the table");
eq(S("timer pâtes", { entries: [{ name: "pâtes", seconds: 660 }] }).source, "mine", "user entry is mine");
eq(S("timer pâtes", { entries: [{ name: "pâtes", seconds: 660 }], recents: recents }).ms, 480000, "last run before user entry");

// Bad own data falls back to the table, never throws
for (const bad of [[{ ms: 500, label: "pâtes", last: t0 }], [{ ms: 101 * 3600000, label: "pâtes" }], [{ ms: NaN, label: "pâtes" }], [{ ms: "600000", label: "pâtes" }], [{ ms: 600000, label: 7 }], [null], "x", 5, {}])
    eq(S("timer pâtes", { recents: bad, history: bad }).source, "table", "bad own data " + JSON.stringify(bad));
eq(S("timer pâtes", { history: { records: [{ name: "pâtes", start: t0, end: "x" }] } }).source, "table", "bad history record");

// Nothing to propose
eq(S("timer"), null, "trigger alone");
eq(S("timer 🍝"), null, "emoji alone");
eq(S("timer unicorn"), null, "unknown name");
eq(S(""), null, "empty");
eq(S(null), null, "null");
eq(S(42), null, "number");
eq(S("timer " + "x".repeat(200)), null, "too long");
done();
