// Variants.js tests — run with: gjs -m tests/variants.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const V = load("components/settings/Variants.js");

eq(V.keys(), ["journal", "favourites", "notice", "endMode"], "the four keys");
const defaults = { journal: "strata", favourites: "glasses", notice: "pill", endMode: "ask" };
const others = { journal: "threads", favourites: "rows", notice: "card", endMode: "auto" };
for (const k of V.keys()) {
    eq(V.defaultOf(k), defaults[k], k + " default");
    eq(V.clean(k, defaults[k]), defaults[k], k + " allowed default");
    eq(V.clean(k, others[k]), others[k], k + " allowed option");
    for (const bad of [undefined, null, "", " ", "Strata", "AUTO", "nope", 0, 1, true, {}, [], ["auto"], { toString: () => "auto" }, "a".repeat(5000), others[k] + " ", others[k] + "x".repeat(40)])
        eq(V.clean(k, bad), defaults[k], k + " damaged input " + JSON.stringify(bad));
}
eq(V.clean("endMode", "auto"), "auto", "auto only for exactly auto");
for (const bad of [undefined, null, "Auto", "auto ", "autoauto", 1, true, {}, "auto".padEnd(100, "o")])
    eq(V.clean("endMode", bad), "ask", "endMode never auto from " + JSON.stringify(bad));
eq(V.clean("nope", "strata"), "", "unknown key");
eq(V.clean("__proto__", "x"), "", "prototype key");
eq(V.clean("hasOwnProperty", "x"), "", "inherited key");
eq(V.defaultOf("nope"), "", "unknown key default");
eq(V.choices("nope"), [], "unknown key choices");
eq(V.choices("journal"), [{ value: "strata", label: "Strata" }, { value: "threads", label: "Threads" }], "journal choices");
eq(V.choices("favourites"), [{ value: "glasses", label: "Three glasses" }, { value: "rows", label: "Rows" }], "favourites choices");
eq(V.choices("notice"), [{ value: "pill", label: "Pill whisper" }, { value: "card", label: "Quiet card" }], "notice choices");
eq(V.choices("endMode"), [{ value: "ask", label: "Ask first" }, { value: "auto", label: "Last grains" }], "endMode choices");
for (const k of V.keys())
    eq(V.choices(k)[0].value, V.defaultOf(k), k + " default first");
const c = V.choices("journal"); c[0].value = "x";
eq(V.choices("journal")[0].value, "strata", "choices returns a copy");
eq(V.keys().every(k => V.choices(k).every(x => !/[—–]/.test(x.label))), true, "no dash in labels");
done();
