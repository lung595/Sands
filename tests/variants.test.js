// Variants.js tests — run with: gjs -m tests/variants.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const V = load("components/settings/Variants.js");

eq(V.keys(), ["journal", "favourites", "notice"], "the three keys");
const defaults = { journal: "strata", favourites: "glasses", notice: "pill" };
const others = { journal: "threads", favourites: "rows", notice: "card" };
for (const k of V.keys()) {
    eq(V.defaultOf(k), defaults[k], k + " default");
    eq(V.clean(k, defaults[k]), defaults[k], k + " allowed default");
    eq(V.clean(k, others[k]), others[k], k + " allowed option");
    for (const bad of [undefined, null, "", " ", "Strata", "AUTO", "nope", 0, 1, true, {}, [], ["auto"], { toString: () => "auto" }, "a".repeat(5000), others[k] + " ", others[k] + "x".repeat(40)])
        eq(V.clean(k, bad), defaults[k], k + " damaged input " + JSON.stringify(bad));
}
// The end mode is gone: a timer always ends the same way
for (const old of ["ask", "auto"])
    eq(V.clean("endMode", old), "", "endMode is no longer a choice (" + old + ")");
eq(V.choices("endMode"), [], "no endMode choices");
eq(V.clean("nope", "strata"), "", "unknown key");
eq(V.clean("__proto__", "x"), "", "prototype key");
eq(V.clean("hasOwnProperty", "x"), "", "inherited key");
eq(V.defaultOf("nope"), "", "unknown key default");
eq(V.choices("nope"), [], "unknown key choices");
eq(V.choices("journal"), [{ value: "strata", label: "Strata" }, { value: "threads", label: "Threads" }], "journal choices");
eq(V.choices("favourites"), [{ value: "glasses", label: "Three glasses" }, { value: "rows", label: "Rows" }], "favourites choices");
eq(V.choices("notice"), [{ value: "pill", label: "Pill whisper" }, { value: "card", label: "Quiet card" }], "notice choices");
for (const k of V.keys())
    eq(V.choices(k)[0].value, V.defaultOf(k), k + " default first");
const c = V.choices("journal"); c[0].value = "x";
eq(V.choices("journal")[0].value, "strata", "choices returns a copy");
eq(V.keys().every(k => V.choices(k).every(x => !/[—–]/.test(x.label))), true, "no dash in labels");
done();
