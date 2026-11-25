// Variants.js tests — run with: gjs -m tests/variants.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const V = load("components/settings/Variants.js");

eq(Object.keys(V.VARIANTS), ["journal", "favourites", "notice"], "the three keys");
const defaults = { journal: "strata", favourites: "glasses", notice: "pill" };
const others = { journal: "threads", favourites: "rows", notice: "card" };
for (const k of Object.keys(V.VARIANTS)) {
    eq(V.defaultOf(k), defaults[k], k + " default");
    eq(V.clean(k, defaults[k]), defaults[k], k + " allowed default");
    eq(V.clean(k, others[k]), others[k], k + " allowed option");
    for (const bad of [undefined, null, "", " ", "Strata", "AUTO", "nope", 0, 1, true, {}, [], ["auto"], { toString: () => "auto" }, "a".repeat(5000), others[k] + " ", others[k] + "x".repeat(40)])
        eq(V.clean(k, bad), defaults[k], k + " damaged input " + JSON.stringify(bad));
}
// The end mode is gone: a timer always ends the same way
for (const old of ["ask", "auto"])
    eq(V.clean("endMode", old), "", "endMode is no longer a choice (" + old + ")");
eq(V.clean("nope", "strata"), "", "unknown key");
eq(V.clean("__proto__", "x"), "", "prototype key");
eq(V.clean("hasOwnProperty", "x"), "", "inherited key");
eq(V.defaultOf("nope"), "", "unknown key default");
eq(V.VARIANTS.journal.concat(V.VARIANTS.favourites, V.VARIANTS.notice).map(c => c.label), ["Strata", "Threads", "Three glasses", "Rows", "Pill whisper", "Quiet card"], "labels");
eq(Object.values(V.VARIANTS).every(l => l.every(x => !/[—–]/.test(x.label))), true, "no dash in labels");
done();
