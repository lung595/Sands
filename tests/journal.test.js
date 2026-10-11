// Journal.js tests — run with: gjs -m tests/journal.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const J = load("components/journal/Journal.js");

eq(J.duration(12 * 60000), "12 min", "minutes");
eq(J.duration(59 * 60000), "59 min", "just under an hour");
eq(J.duration(60 * 60000), "1 h", "one hour");
eq(J.duration(360 * 60000), "6 h", "round hours");
eq(J.duration(645 * 60000), "10 h 45", "hours and minutes");
eq(J.duration(125 * 60000), "2 h 05", "minutes padded");
eq(J.duration(5000), "1 min", "a few seconds is one minute");
eq(J.duration(NaN), "1 min", "damaged time");
eq(J.plain("Kate — notes"), "Kate - notes", "em dash replaced");
eq(J.plain("a–b"), "a - b", "en dash replaced");
eq(J.plain("plain-name"), "plain-name", "hyphen kept");

const demo = [["work", 360], ["reading", 150], ["laundry", 75], ["pasta", 48], ["tea", 12]].map(a => ({ name: a[0], ms: a[1] * 60000 }));
eq(J.rows(demo, J.STRATA_MAX).length, 5, "five names stay five");
const many = demo.concat([["stretch", 40], ["call", 35], ["nap", 30], ["bread", 25], ["plants", 10], ["eggs", 9], ["rice", 6]].map(a => ({ name: a[0], ms: a[1] * 60000 })));
const s = J.rows(many, J.STRATA_MAX);
eq(s.length, 5, "twelve names fold to five layers");
eq(s[4], { name: "8 more names", ms: 167 * 60000, folded: 8 }, "strata fold sums the rest");
const t = J.rows(many, J.THREADS_MAX);
eq(t.length, 7, "twelve names fold to seven threads");
eq(t[6].name, "6 more names", "threads fold label");
eq(J.rows(many.slice(0, 7), J.THREADS_MAX).length, 7, "seven names are not folded");
eq(J.rows([], 5), [], "empty");

const h = J.layerHeights(J.rows(demo, 5));
eq(h.length, 5, "one height per layer");
eq(Math.round(h.reduce((a, x) => a + x, 0)), 83, "layers fill 80 units plus the 4 minimum of the smallest");
eq(J.layerHeights([{ ms: 1 }, { ms: 1e9 }])[0], 4, "a tiny value keeps 4 units");
eq(J.layerHeights([]), [], "no layers");
const f = J.threadFractions(J.rows(demo, 7));
eq(f[0], 1, "longest thread is full");
eq(f[4], 12 / 360, "others in proportion");
eq(J.threadFractions([]), [], "no threads");
eq([0, 1, 2, 3, 4, 5, 6].map(J.textureOf), [0, 1, 2, 3, 4, 0, 1], "texture cycle");
done();
