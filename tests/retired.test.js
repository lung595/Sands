// Retired.js tests — run with: gjs tests/retired.test.js (from the plugin root)
// The settings an older Sands saved and this one drops at start.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const R = load("components/daemon/Retired.js");

eq(R.KEYS, ["endMode", "timerEndMode", "personalActions", "actionWords"], "the retired keys");
eq(R.END_ACTION_KEYS, ["personalActions", "actionWords"], "the end actions' keys");

const old = { endMode: "auto", timerEndMode: "alex", sound: "hourglass", notify: false, volume: 80 };
const r = R.sweep(old);
eq(r.settings, { sound: "hourglass", notify: false, volume: 80 }, "old end modes dropped, the rest kept as is");
eq(r.removed, ["endMode", "timerEndMode"], "what was dropped");
eq(r.hadEndActions, false, "an end mode is not an end action");
eq(old.endMode, "auto", "the input is not changed");

eq(R.sweep({ endMode: "ask" }), { settings: {}, removed: ["endMode"], hadEndActions: false }, "only an end mode");
eq(R.sweep({ sound: "chime" }), { settings: { sound: "chime" }, removed: [], hadEndActions: false }, "nothing to drop");
eq(R.sweep({}), { settings: {}, removed: [], hadEndActions: false }, "empty");
for (const bad of [undefined, null, "endMode", 3, true, ["endMode"]])
    eq(R.sweep(bad), { settings: {}, removed: [], hadEndActions: false }, "not settings: " + JSON.stringify(bad));
// Any value under a retired key goes, even a damaged one
eq(R.sweep({ endMode: { nested: 1 }, tick: true }).settings, { tick: true }, "damaged end mode dropped");
eq(R.sweep({ endMode: null }).removed, ["endMode"], "null end mode dropped");

// The end actions (1.7.0): both keys erased, told only to whoever had some
const actions = {
    personalActions: [{ name: "Lights", program: "lights", args: ["off"] }],
    actionWords: { poweroff: ["off", "dodo"] },
    sound: "chime"
};
const a = R.sweep(actions);
eq(a.settings, { sound: "chime" }, "end-action keys erased, the rest kept");
eq(a.removed, ["personalActions", "actionWords"], "both end-action keys dropped");
eq(a.hadEndActions, true, "own commands and words: had end actions");
eq(actions.personalActions.length, 1, "the input is not changed");
eq(R.sweep({ personalActions: [{ name: "Lights", program: "lights" }] }).hadEndActions, true, "own commands only");
eq(R.sweep({ actionWords: { suspend: ["nap"] } }).hadEndActions, true, "changed words only");
// Saved but empty (a command added then removed, words reset): nothing to tell
const empty = R.sweep({ personalActions: [], actionWords: {}, tick: true });
eq([empty.settings, empty.removed, empty.hadEndActions], [{ tick: true }, ["personalActions", "actionWords"], false], "empty end actions erased, nothing to tell");
for (const bad of [null, "off", 3, true])
    eq(R.sweep({ personalActions: bad, actionWords: bad }).hadEndActions, false, "damaged end actions erased silently: " + JSON.stringify(bad));
eq(R.sweep({ personalActions: null }).removed, ["personalActions"], "a damaged key goes too");

// The toast: once ever, only if there were end actions
eq(R.notice(true, false), true, "had some, first start: told");
eq(R.notice(true, true), false, "had some, already told: never again");
eq(R.notice(false, false), false, "had none: not told");
eq(R.notice(false, true), false, "had none, already done: not told");
eq(R.notice(undefined, undefined), false, "nothing known: not told");
eq(R.NOTICE_KEY, "endActionsRetired", "the flag in the plugin state");
eq(R.toastText("fr_FR"), "Actions de fin retirées", "French toast");
eq(R.toastText("fr_CA"), "Actions de fin retirées", "French toast (Canada)");
eq([R.toastText("en_GB"), R.toastText("de_DE"), R.toastText(""), R.toastText(undefined)], ["End actions removed", "End actions removed", "End actions removed", "End actions removed"], "English toast otherwise");

// A saved timer that had an end action ends as any other: the field goes
const running = { id: 2, label: "Film", state: "running", endAt: 5000, total: 2700000, actionId: "poweroff" };
const plain = { id: 3, label: "Tea", state: "paused", remaining: 1000 };
const stripped = R.stripTimers([running, plain]);
eq(stripped, [{ id: 2, label: "Film", state: "running", endAt: 5000, total: 2700000 }, plain], "end action dropped, the rest kept");
eq(running.actionId, "poweroff", "the saved timer is not changed");
eq(stripped[1] === plain, true, "a timer without end action is kept as is");
eq(R.stripTimers([{ id: 4, actionId: undefined }]), [{ id: 4 }], "even an empty end action goes");
eq(R.stripTimers([]), [], "no timer");
eq(R.stripTimers([null, 3, "x"]), [null, 3, "x"], "odd entries are left to the restore");
for (const bad of [undefined, null, "timers", 3, { id: 1 }])
    eq(R.stripTimers(bad), bad, "not a list, given back: " + JSON.stringify(bad));

done();
