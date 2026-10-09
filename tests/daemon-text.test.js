// IpcReplies.js and Notifications.js tests — run with: gjs tests/daemon-text.test.js
// Every sentence `dms ipc call smartTimer` answers and every command line of
// the end notification, pinned because scripts and the notification daemon
// read them.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const R = load("components/daemon/IpcReplies.js");
const N = load("components/daemon/Notifications.js");

const G = "https://example.test/GUIDE.md";

// start
eq(R.tooLong(G), "Not started: keep it under 200 characters, like \"12 min pasta\": " + G + "#syntax", "too long");
eq(R.notUnderstood(G), "Not started. Try \"12 min pasta\": " + G + "#syntax", "not understood");
const refusal = { hint: "At most 50 timers at once: cancel one first", anchor: "syntax" };
eq(R.started({ started: 0, count: 1 }, refusal, 50, G, true), "Not started: At most 50 timers at once: cancel one first. " + G + "#syntax", "refused");
eq(R.started({ started: 1, count: 1, kind: "duration", label: "pasta", ms: 720000 }, null, 50, G, true), "Started: pasta — 12 min", "one named timer");
eq(R.started({ started: 1, count: 1, kind: "duration", label: "", ms: 60000 }, null, 50, G, true), "Started: Timer — 1 min", "one unnamed timer");
eq(R.started({ started: 4, count: 4, kind: "duration", label: "", ms: 3600000 }, null, 50, G, true), "Started: 4 × Timer — 1 h", "several");
eq(R.started({ started: 2, count: 4, kind: "duration", label: "", ms: 3600000 }, null, 50, G, true), "Started: 2 of 4 × Timer — 1 h (at most 50 at once: " + G + "#syntax)", "partly");
const at = new Date(2026, 0, 1, 14, 5).getTime();
eq(R.started({ started: 1, count: 1, kind: "at", label: "", at: at }, null, 50, G, true), "Started: Alarm — at 14:05", "an alarm, 24 h clock");
eq(R.notChanged(G), "Not changed: a timer lasts between 1 second and 100 hours. " + G + "#syntax", "not changed");

// list
eq(R.list([], 0), "No timer", "empty list");
eq(R.list([
    { state: "ringing", label: "tea", finishedAt: 0 },
    { state: "running", label: "", kind: "duration", endAt: 65000 },
    { state: "paused", label: "", kind: "at", remaining: 5000 }
], 0), "tea\t0:00 (done)\nTimer\t1:05\nAlarm\t0:05 (paused)", "one line per timer, tab separated");

// Notification
eq(N.body({ kind: "duration", total: 300000 }, true), "5 min elapsed", "a duration timer");
eq(N.body({ kind: "at", endAt: at }, true), "It's 14:05", "an alarm");
const show = N.showCommand("tea", "5 min elapsed");
eq(show.slice(0, 3), ["notify-send", "-a", "Sands"], "notify-send, app name Sands");
eq(show.slice(-2), ["tea — done", "5 min elapsed"], "title then body, as separate arguments");
eq(show.filter(a => a.startsWith("snooze=")), ["snooze=+5 min"], "a snooze button");
eq(N.closeCommand(42).slice(-2), ["org.freedesktop.Notifications.CloseNotification", "42"], "close by id");
eq(N.parseLine(" 17\n"), { id: 17 }, "the id line");
eq(N.parseLine("stop"), { action: "stop" }, "the stop button");
eq(N.parseLine("snooze"), { action: "snooze" }, "the snooze button");
eq(N.parseLine("anything else"), null, "other output is ignored");
eq(N.parseLine("1 2"), null, "not an id");

done();
