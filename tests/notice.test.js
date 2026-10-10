// Notice.js tests — run with: gjs tests/notice.test.js (from the plugin root)
// The notice before the end: silent by default, never for short timers,
// never twice, and right across pause and resume.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const N = load("components/daemon/Notice.js");

const MIN = 60000;
const run = (id, total, endAt) => ({ id: id, state: "running", total: total, endAt: endAt, remaining: 0 });

// Setting to ms: silent by default and for bad values
eq(N.noticeMs(undefined), 0, "missing is silent");
eq(N.noticeMs(0), 0, "zero is silent");
eq(N.noticeMs(-3), 0, "negative is silent");
eq(N.noticeMs("abc"), 0, "text is silent");
eq(N.noticeMs(2), 2 * MIN, "2 minutes");
eq(N.noticeMs(2.9), 2 * MIN, "fraction is floored");
eq(N.noticeMs(61), 0, "above the cap is silent");

// Due time and trigger
const t = run("a", 10 * MIN, 10 * MIN);
eq(N.dueAt(t, 0, []), -1, "silent: nothing due");
eq(N.dueAt(t, 2 * MIN, []), 8 * MIN, "due 2 min before the end");
eq(N.isDue(t, 8 * MIN - 1, 2 * MIN, []), false, "not yet");
eq(N.isDue(t, 8 * MIN, 2 * MIN, []), true, "due at the mark");
eq(N.isDue(t, 10 * MIN, 2 * MIN, []), false, "at the end the alarm takes over");

// Too short: equal or shorter than the notice never gets one
eq(N.dueAt(run("b", 2 * MIN, 2 * MIN), 2 * MIN, []), -1, "same length: none");
eq(N.dueAt(run("b", MIN, MIN), 2 * MIN, []), -1, "shorter: none");

// Never twice
const done1 = N.markNotified([], "a");
eq(N.isDue(t, 9 * MIN, 2 * MIN, done1), false, "already notified");
eq(N.markNotified(done1, "a"), ["a"], "marking twice keeps one");
eq(N.markNotified([], "a") !== N.markNotified([], "a"), true, "new array each time");

// Pause and resume: the mark follows endAt
const paused = { id: "a", state: "paused", total: 10 * MIN, endAt: 0, remaining: 5 * MIN };
eq(N.dueAt(paused, 2 * MIN, []), -1, "paused: nothing to wait for");
const resumed = run("a", 10 * MIN, 100 * MIN + 5 * MIN);
eq(N.dueAt(resumed, 2 * MIN, []), 103 * MIN, "resumed: mark moved with the end");
eq(N.isDue(resumed, 102 * MIN, 2 * MIN, []), false, "resumed: not due early");
eq(N.isDue(resumed, 103 * MIN, 2 * MIN, []), true, "resumed: due at the new mark");
eq(N.isDue(resumed, 103 * MIN, 2 * MIN, done1), false, "paused after the notice: not again");
eq(N.dueAt({ id: "r", state: "ringing", total: 10 * MIN, endAt: 0 }, 2 * MIN, []), -1, "ringing: none");

// Next wake-up
eq(N.nextDueAt([], 2 * MIN, []), -1, "no timers: no wake-up");
eq(N.nextDueAt([t, run("c", 5 * MIN, 5 * MIN)], 2 * MIN, []), 3 * MIN, "soonest mark");
eq(N.nextDueAt([t], 2 * MIN, ["a"]), -1, "all notified: no wake-up");

// Bounded list and pruning
let ids = [];
for (let i = 0; i < 100; i++)
    ids = N.markNotified(ids, "t" + i);
eq(ids.length, 64, "capped");
eq(ids[63], "t99", "keeps the newest");
eq(N.prune(["a", "z"], [t]), ["a"], "prune drops gone timers");
done();
