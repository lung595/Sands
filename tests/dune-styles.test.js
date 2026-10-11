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
done();
