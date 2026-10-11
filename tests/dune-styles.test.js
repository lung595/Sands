// DuneStyles.js tests — run with: gjs tests/dune-styles.test.js
// The three values, their texts, and the fallback of a bad saved value.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const S = load("components/alert/DuneStyles.js");

eq(S.STYLES.map(s => s.value), ["grains", "wind", "wave"], "three values in order");
eq(S.STYLES.map(s => s.label), ["Last grains", "Wind dune", "Flat wave"], "labels");
eq(S.STYLES.every(s => s.help.length > 0 && !/[—–]/.test(s.help + s.label)), true, "one help line each, no em dash");
eq(S.DEFAULT, "grains", "default is grains");
for (const v of ["grains", "wind", "wave"]) eq(S.resolve(v), v, "keeps " + v);
for (const v of [undefined, null, "", "Wave", "sand", 3]) eq(S.resolve(v), "grains", "falls back from " + String(v));
eq(S.labelOf("nope"), "Last grains", "label of a bad value");
eq(S.helpOf("wind"), S.STYLES[1].help, "help of wind");

// Which styles have a scene today, and what the settings cards say about the others
const GLib = imports.gi.GLib;
const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
for (const [k, file] of Object.entries(S.SCENES)) {
    eq(S.STYLES.some(s => s.value === k), true, "a scene belongs to a known style: " + k);
    eq(GLib.file_test(dir + "/components/alert/" + file, GLib.FileTest.EXISTS), true, "the scene file exists: " + file);
}
eq(S.isDrawn(S.DEFAULT), true, "the default style has its scene");
eq([S.isDrawn("nope"), S.isDrawn("toString"), S.isDrawn(undefined)], [false, false, false], "unknown values have no scene");
for (const s of S.STYLES)
    eq(S.drawnOf(s.value), S.isDrawn(s.value) ? s.value : S.DEFAULT, "what is drawn for " + s.value);
eq(S.drawnOf("nope"), "grains", "a bad value draws the default");
eq(S.STYLES.map(s => S.isDrawn(s.value)), [true, true, true], "the three styles have their scene");
const cards = S.choices();
eq(cards.map(c => c.value), S.STYLES.map(s => s.value), "one card per style, same order");
eq(cards.map(c => c.enabled), S.STYLES.map(s => S.isDrawn(s.value)), "only a style with a scene can be picked");
eq(cards.every(c => c.label && c.help && c.reason === "Not available yet"), true, "every card has its texts and the reason shown when greyed");
done();
