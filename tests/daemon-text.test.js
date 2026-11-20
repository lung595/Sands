// IpcReplies.js and Notifications.js tests - run with: gjs tests/daemon-text.test.js
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
eq(R.started({ started: 1, count: 1, kind: "duration", label: "pasta", ms: 720000 }, null, 50, G, true), "Started: pasta - 12 min", "one named timer");
eq(R.started({ started: 1, count: 1, kind: "duration", label: "", ms: 60000 }, null, 50, G, true), "Started: Timer - 1 min", "one unnamed timer");
eq(R.started({ started: 4, count: 4, kind: "duration", label: "", ms: 3600000 }, null, 50, G, true), "Started: 4 × Timer - 1 h", "several");
eq(R.started({ started: 2, count: 4, kind: "duration", label: "", ms: 3600000 }, null, 50, G, true), "Started: 2 of 4 × Timer - 1 h (at most 50 at once: " + G + "#syntax)", "partly");
const at = new Date(2026, 0, 1, 14, 5).getTime();
eq(R.started({ started: 1, count: 1, kind: "at", label: "", at: at }, null, 50, G, true), "Started: Alarm - at 14:05", "an alarm, 24 h clock");
eq(R.notChanged(G), "Not changed: taking time off stops at 0:10, and a timer lasts at most 100 hours. " + G + "#syntax", "not changed");
eq(R.undone(), "Timer restored", "undo");
eq(R.nothingToUndo(), "Nothing to undo: a stopped timer can be brought back for 5 s", "nothing to undo");

// list
eq(R.list([], 0), "No timer", "empty list");
eq(R.list([
    { state: "ringing", label: "tea", finishedAt: 0 },
    { state: "running", label: "", kind: "duration", endAt: 65000 },
    { state: "paused", label: "", kind: "at", remaining: 5000 }
], 0), "Tea\t0:00 (done)\nTimer\t1:05\nAlarm\t0:05 (paused)", "one line per timer, tab separated, names with a capital");

// Notification
eq(N.body({ kind: "duration", total: 300000 }, true), "5 min elapsed", "a duration timer");
eq(N.body({ kind: "at", endAt: at }, true), "It's 14:05", "an alarm");
const show = N.showCommand("tea", "5 min elapsed");
eq(show.slice(0, 3), ["notify-send", "-a", "Sands"], "notify-send, app name Sands");
eq(show.slice(-2), ["tea - done", "5 min elapsed"], "title then body, as separate arguments");
eq(show.filter(a => a.startsWith("snooze=")), ["snooze=+5 min"], "a snooze button");
eq(N.closeCommand(42).slice(-2), ["org.freedesktop.Notifications.CloseNotification", "42"], "close by id");
eq(N.parseLine(" 17\n"), { id: 17 }, "the id line");
eq(N.parseLine("stop"), { action: "stop" }, "the stop button");
eq(N.parseLine("snooze"), { action: "snooze" }, "the snooze button");
eq(N.parseLine("anything else"), null, "other output is ignored");
eq(N.parseLine("1 2"), null, "not an id");

// French when a language is passed (last argument), English otherwise
eq(R.started({ started: 2, count: 4, kind: "duration", label: "", ms: 3600000 }, null, 50, G, true, "fr"), "Démarré : 2 sur 4 × Minuteur - 1 h (50 au plus à la fois : " + G + "#syntax)", "partly, French");
eq(R.started({ started: 1, count: 1, kind: "at", label: "", at: at }, null, 50, G, true, "fr_FR"), "Démarré : Alarme - à 14:05", "an alarm, French");
eq(R.started({ started: 0, count: 1 }, { hint: "x", anchor: "syntax" }, 50, G, true, "fr"), "Pas démarré : x. " + G + "#syntax", "refused, French");
eq(R.tooLong(G, "fr"), "Pas démarré : moins de 200 caractères, comme « 12 min pâtes » : " + G + "#syntax", "too long, French");
eq(R.undone("fr"), "Minuteur rétabli", "undo, French");
eq(R.list([], 0, "fr"), "Aucun minuteur", "empty list, French");
eq(R.list([{ state: "paused", label: "", kind: "at", remaining: 5000 }], 0, "fr"), "Alarme\t0:05 (en pause)", "list, French");
eq(N.body({ kind: "duration", total: 300000 }, true, "fr"), "Temps écoulé : 5 min", "notification body, French");
eq(N.body({ kind: "at", endAt: at }, true, "fr"), "Il est 14:05", "alarm body, French");
const showFr = N.showCommand("thé", "x", "fr");
eq(showFr.filter(a => /^(stop|snooze)=/.test(a)), ["stop=Arrêter", "snooze=+5 min"], "French buttons keep their ids");
eq(showFr.slice(-2)[0], "thé - terminé", "French title");

// A dash typed in a label is shown as a hyphen
eq(R.started({ started: 1, count: 1, kind: "duration", label: "a\u2014b \u2013 c", ms: 60000 }, null, 50, G, true), "Started: a - b - c - 1 min", "dashes in a label, reply");
eq(N.showCommand("a\u2014b", "x").slice(-2)[0], "a - b - done", "dashes in a label, title");

eq(R.list([{ state: "running", label: "a\u2014b", kind: "duration", endAt: 65000 }], 0), "A - b\t1:05", "dashes in a label, list");
eq(R.started({ started: 1, count: 1, kind: "duration", label: "a \u2014 \u2014 b", ms: 60000 }, null, 50, G, true), "Started: a - b - 1 min", "two dashes in a row");

// No user-facing string of components/ holds an em or en dash. Scanned in JS
// from the plugin root: independent of the working directory and the locale.
const { dir, read } = imports.harness;
const GLib = imports.gi.GLib;
const sources = sub => {
    const d = GLib.Dir.open(dir + "/" + sub, 0);
    const found = [];
    let name;
    while ((name = d.read_name()) !== null) {
        const path = sub + "/" + name;
        if (GLib.file_test(dir + "/" + path, GLib.FileTest.IS_DIR))
            found.push(...sources(path));
        else if (/\.(qml|js)$/.test(name))
            found.push(path);
    }
    return found;
};
const all = sources("components");
eq(all.length > 20, true, "the scan finds the sources");
eq(all.filter(f => /[\u2013\u2014]/.test(read(f))), [], "no em or en dash in components/");
eq(JSON.parse(R.snoozed(5)), { snoozed: true, minutes: 5 }, "reply: snoozed is JSON");
eq(R.collecting("G"), "Collecting (about 2 s): run the same command again. G#report-a-problem", "reply: collecting");
eq(R.stillCollecting("G"), "Still collecting, ask again in a moment. G#report-a-problem", "reply: still collecting");
eq(JSON.parse(R.notRinging()), { snoozed: false, reason: "nothing is ringing" }, "reply: not ringing is JSON");

done();
