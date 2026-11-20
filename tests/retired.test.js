// Retired.js tests — run with: gjs tests/retired.test.js (from the plugin root)
// The settings an older Sands saved and this one drops at start.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const R = load("components/daemon/Retired.js");

eq(R.KEYS, ["endMode", "timerEndMode"], "the retired keys");

const old = { endMode: "auto", timerEndMode: "alex", sound: "hourglass", notify: false, volume: 80 };
const r = R.sweep(old);
eq(r.settings, { sound: "hourglass", notify: false, volume: 80 }, "old end modes dropped, the rest kept as is");
eq(r.removed, ["endMode", "timerEndMode"], "what was dropped");
eq(old.endMode, "auto", "the input is not changed");

eq(R.sweep({ endMode: "ask" }), { settings: {}, removed: ["endMode"] }, "only an end mode");
eq(R.sweep({ sound: "chime" }), { settings: { sound: "chime" }, removed: [] }, "nothing to drop");
eq(R.sweep({}), { settings: {}, removed: [] }, "empty");
for (const bad of [undefined, null, "endMode", 3, true, ["endMode"]])
    eq(R.sweep(bad), { settings: {}, removed: [] }, "not settings: " + JSON.stringify(bad));
// Any value under a retired key goes, even a damaged one
eq(R.sweep({ endMode: { nested: 1 }, tick: true }).settings, { tick: true }, "damaged end mode dropped");
eq(R.sweep({ endMode: null }).removed, ["endMode"], "null end mode dropped");

done();
