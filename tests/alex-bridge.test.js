// AlexBridge.js tests — run with: gjs tests/alex-bridge.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const A = load("AlexBridge.js");

const t = { id: 3, label: "pasta", endAt: 1000, finishedAt: 1005 };
const e = A.buildEvent(t, 1);
eq(e, { kind: "timerFinished", id: "1005-3-1", label: "pasta", endAt: 1005 }, "event shape");
eq(Object.keys(e), ["kind", "id", "label", "endAt"], "only whitelisted fields");
eq(A.buildEvent(t, 2).id === e.id, false, "id changes per ring");
eq(A.buildEvent({ id: 3, label: "x", endAt: 7 }, 1).endAt, 7, "falls back to endAt");
eq(A.buildEvent({ id: 1, label: "a".repeat(500), endAt: 1 }, 1).label.length, 60, "label capped");
eq(A.buildEvent({ id: 1, label: "a\nb\u0000c", endAt: 1 }, 1).label, "a b c", "control characters removed");
eq(A.buildEvent({ id: 1, endAt: 1 }, 1).label, "", "missing label");
eq(A.buildEvent({ id: 1, label: 5, endAt: 1 }, 1).label, "", "non-text label");
// --- the shared timer-end choice -------------------------------------------
eq(A.MODES.map(m => m.value), ["sands", "react", "alex"], "three modes in order");
eq(A.choices()[1].label, "Sands + Alex reacts", "default agent name");
eq(A.readArgs(), ["ipc", "call", "alex", "timerEndMode"], "read arguments");
eq(A.setArgs("alex"), ["ipc", "call", "alex", "timerEndMode", "alex"], "set arguments");
eq(A.setArgs("--help"), null, "unknown value refused");
eq(A.setArgs("sands; rm"), null, "metacharacters refused");
eq(A.setArgs(undefined), null, "missing value refused");
eq(A.parseReply("react\n"), "react", "reply is trimmed");
eq(A.parseReply("Target not found.\n"), "", "missing target is unavailable");
eq(A.parseReply(""), "", "empty reply");
eq(A.parseReply("x".repeat(500)), "", "oversized reply");
eq(A.parseReply(null), "", "non-text reply");
eq(A.noticeMode({ kind: "timerEndModeChanged", mode: "sands" }), "sands", "notice mode");
eq(A.noticeMode({ kind: "other", mode: "sands" }), "", "other notice ignored");
eq(A.noticeMode({ kind: "timerEndModeChanged", mode: "zzz" }), "", "unknown notice mode ignored");
eq(A.noticeMode(null), "", "null notice");
eq(A.rowState(true, "react"), { enabled: true, selected: "react", batteryChip: true }, "react: chip");
eq(A.rowState(true, "alex"), { enabled: true, selected: "alex", batteryChip: true }, "alex island: chip");
eq(A.rowState(true, "sands"), { enabled: true, selected: "sands", batteryChip: false }, "Sands only: no chip");
eq(A.rowState(false, "react"), { enabled: false, selected: "", batteryChip: false }, "no Alex: greyed, nothing checked, no chip");
eq(A.rowState(true, ""), { enabled: false, selected: "", batteryChip: false }, "unread: greyed");
done();
