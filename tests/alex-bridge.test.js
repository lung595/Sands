// AlexBridge.js tests — run with: gjs tests/alex-bridge.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const A = load("AlexBridge.js");

const t = { id: 3, label: "pasta", endAt: 1000, finishedAt: 1005 };
const e = A.buildEvent(t, 1);
eq(e, { id: "1005-3-1", label: "pasta", endAt: 1005 }, "event shape");
eq(Object.keys(e), ["id", "label", "endAt"], "only whitelisted fields");
eq(A.buildEvent(t, 2).id === e.id, false, "id changes per ring");
eq(A.buildEvent({ id: 3, label: "x", endAt: 7 }, 1).endAt, 7, "falls back to endAt");
eq(A.buildEvent({ id: 1, label: "a".repeat(500), endAt: 1 }, 1).label.length, 60, "label capped");
eq(A.buildEvent({ id: 1, label: "a\nb\u0000c", endAt: 1 }, 1).label, "a b c", "control characters removed");
eq(A.buildEvent({ id: 1, endAt: 1 }, 1).label, "", "missing label");
eq(A.buildEvent({ id: 1, label: 5, endAt: 1 }, 1).label, "", "non-text label");
eq(A.alexShowsAlarm("island"), true, "island choice");
eq(A.alexShowsAlarm("sands"), false, "sands choice");
eq(A.alexShowsAlarm(undefined), false, "failed read keeps Sands alarm");
eq(A.alexShowsAlarm(null), false, "null keeps Sands alarm");
done();
