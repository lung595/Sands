// Status.js tests — run with: gjs tests/status.test.js
// The JSON a script reads from `dms ipc call smartTimer status`, pinned.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const S = load("components/daemon/Status.js");

const now = 1000000;
const parse = list => JSON.parse(S.build(list, now));

// no timer
eq(parse([]), { count: 0, ringing: false, timers: [] }, "empty list");

// running: 90.2 s left rounds up so a script never sees 0 while it runs
const run = { id: "a", state: "running", total: 120000, endAt: now + 90200, label: "pasta", kind: "duration" };
eq(parse([run]), { count: 1, ringing: false, timers: [{ id: "a", label: "pasta", phase: "running", remaining: 91, total: 120 }] }, "one running");

// paused keeps its remaining time, unnamed falls back to the kind
const paused = { id: "b", state: "paused", total: 60000, remaining: 30000, kind: "duration" };
eq(parse([paused]).timers[0], { id: "b", label: "Timer", phase: "paused", remaining: 30, total: 60 }, "paused");

// ringing: never negative, flag set
const ring = { id: "c", state: "ringing", total: 5000, finishedAt: now - 4000, kind: "at" };
const r = parse([ring]);
eq(r.timers[0], { id: "c", label: "Alarm", phase: "ringing", remaining: 0, total: 5 }, "ringing");
eq(r.ringing, true, "ringing flag");

// several keep the given order
eq(parse([run, paused, ring]).timers.map(t => t.id), ["a", "b", "c"], "several, in order");

// caps
const many = Array.from({ length: 150 }, (_, i) => ({ id: "t" + i, state: "paused", total: 1000, remaining: 1000 }));
const capped = parse(many);
eq(capped.timers.length, 100, "list capped");
eq(capped.count, 150, "count is the real total");
eq(parse([{ id: "x", state: "paused", total: 1000, remaining: 1000, label: "a".repeat(500) }]).timers[0].label.length, 200, "label capped");
done();
