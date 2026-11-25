// components/launcher/Card.js tests (and the "Stopped · Undo" items of
// Section.js) — run with: gjs tests/launcher-card.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const C = load("components/launcher/Card.js");
const S = load("components/launcher/Section.js");

const T0 = Date.UTC(2026, 10, 20, 17, 0, 0);
const run = (id, left, total, label) => ({ id, label: label || "", kind: "duration", state: "running", endAt: T0 + left, total: total || 900000, remaining: 0, finishedAt: 0 });
const paused = (id, left, label) => ({ id, label: label || "", kind: "duration", state: "paused", endAt: 0, total: 900000, remaining: left, finishedAt: 0 });
const ring = (id, ago, label) => ({ id, label: label || "", kind: "duration", state: "ringing", endAt: T0 - ago, total: 600000, remaining: 0, finishedAt: T0 - ago });

// The time: the countdown, or the overrun growing once it rings
eq(C.clock(run(1, 754000), T0), "12:34", "countdown");
eq(C.clock(paused(1, 61000), T0), "1:01", "paused: frozen time left");
eq(C.clock(ring(1, 42000), T0), "+0:42", "ringing: time since it rang");
eq(C.clock(ring(1, 42000), T0 + 18000), "+1:00", "the overrun grows");
eq(C.overrun(run(1, 5000), T0), 0, "no overrun before it rings");
eq(C.title(run(1, 754000, 900000, "Pâtes"), T0), "Pâtes — 12:34", "collapsed title");
eq(C.title(null, T0), "", "no timer, no title");
eq(C.title(run(1, 215000, 900000, "thé"), T0), "Thé — 3:35", "a name typed in lower case gets a capital");

// The end: the time of day it rings, in the DMS 12/24 h setting
eq(C.endText(run(1, 6 * 60000 + 42 * 60000), true).length, 5, "24 h end");
eq(/[AP]M$/.test(C.endText(run(1, 60000), false)), true, "12 h end");
eq(C.endText(paused(1, 60000), true), "", "paused: no end");
eq(C.endText(ring(1, 1000), true) !== "", true, "ringing: when it rang");

// Short durations and the notice
eq([C.shortDuration(45000), C.shortDuration(600000), C.shortDuration(3600000), C.shortDuration(5400000), C.shortDuration(0)], ["45s", "10m", "1h", "1h30", "0s"], "short durations");
eq([C.noticeText(2), C.noticeText(0), C.noticeText(undefined), C.noticeText("x")], ["2m", "", "", ""], "notice, or none");

// The notice the daemon gives: missing setting = 2 min, off at 0, none for
// a timer not longer than the notice
eq(C.noticeMinutes(run(1, 60000, 900000), undefined), 2, "unset: the 2 min default");
eq(C.noticeMinutes(run(1, 60000, 900000), 5), 5, "set to 5");
eq(C.noticeMinutes(run(1, 60000, 900000), 0), 0, "off");
eq(C.noticeMinutes(run(1, 60000, 90000), undefined), 0, "too short for a notice");
eq(C.noticeMinutes(null, 2), 0, "no timer");

// The tooltip of the hourglass carries the only percentage
eq(/50 %$/.test(C.glassTip(run(1, 450000, 900000), T0, true)), true, "percent in the tooltip");
eq(C.glassTip(paused(1, 450000), T0, true), "50 %", "paused: the percentage alone");

// Snooze: three choices, the last one picked first
eq(C.snoozeChoices(null, 0), [1, 5, 10], "default choices");
eq(C.snoozeChoices([1, 5, 10], 10), [10, 1, 5], "last used first");
eq(C.snoozeChoices([2, 3, 4, 5], 0), [2, 3, 4], "at most three");

// Rename: emoji dropped, an empty name refused
eq(C.cleanName("  Thé 🍵 vert "), "Thé vert", "emoji dropped");
eq(C.cleanName("🍝"), "", "emoji only: refused");
eq(C.cleanName("   "), "", "empty: refused");
eq(C.cleanName("x".repeat(80)).length, 60, "cut to the label limit");

// Plan dots
eq(C.planDots({ steps: 4, index: 1 }), [true, true, false, false], "plan dots");
eq(C.planDots(null), [], "no plan, no dots");
eq(C.planDots({ steps: 1, index: 0 }), [], "one step, no dots");

// Ids: the card finds the DMS prefix to name its neighbours
eq(C.idPrefix("live:smartTimer:timer:3", "timer:3"), "live:smartTimer:", "DMS prefix");
eq(C.idPrefix("timer:3", "timer:3"), "", "no prefix");

// Keys of the open card: F2 renames, Space pauses only from the controls
eq(C.keyAction("F2", "", "running"), "rename", "F2 renames");
eq(C.keyAction("Space", "", "running"), "", "Space types in the search");
eq(C.keyAction("Space", "controls", "running"), "pause", "Space pauses from the controls");
eq(C.keyAction("Space", "controls", "ringing"), "", "Space does not stop a ringing timer");
eq(C.keyAction("F2", "name", "running"), "", "keys go to the field while renaming");
eq(C.keyAction("Escape", "", "running"), "", "Escape is DMS's");

// Words by language
eq([C.words("fr_FR").others, C.words("en").others, C.words(undefined).undo], ["Autres minuteurs", "Other timers", "Undo"], "words by language");
eq(C.stoppedToast("Thé", "fr"), "Thé · Arrêté", "toast text");
eq(C.UNDO_COMMAND, "dms ipc call smartTimer undo", "undo command");

// Section: a stopped timer stays in place as "Stopped · Undo" for 5 s
const ON = { section: true, duringSearch: true, favourites: true };
const tea = run(1, 190000, 300000, "Tea");
const pasta = run(2, 400000, 900000, "Pasta");
const build = o => S.build(Object.assign({ favourites: [], query: "", trigger: "", settings: ON }, o));
const first = build({ timers: [tea, pasta] });
eq(first.items.map(i => i.id), ["timer:1", "timer:2"], "two cards");
const removed = [{ timer: tea, at: T0 }];
const after = build({ timers: [pasta], prev: first.order, removed: removed, now: T0 + 1000 });
eq(after.items.map(i => i.kind + ":" + i.id), ["stopped:timer:1", "timer:timer:2"], "stopped card in place");
eq(after.items[0].action, "undo:1", "Enter undoes");
eq(after.items[0].at, T0, "the card knows when it stopped");
eq([after.items[0].keepOpen, after.items[0].expandable], [true, false], "undo keeps the launcher open");
const again = build({ timers: [pasta], prev: after.order, removed: removed, now: T0 + 2000 });
eq(again.items.map(i => i.kind), ["stopped", "timer"], "kept on the next refresh");
const late = build({ timers: [pasta], prev: again.order, removed: removed, now: T0 + 5000 });
eq(late.items.map(i => i.kind), ["timer"], "gone after 5 s");
const alone = build({ timers: [], prev: [{ id: 1, state: "running" }], removed: removed, now: T0 + 1000 });
eq(alone.items.map(i => i.kind), ["stopped"], "the last timer stopped still shows its undo");

// A timer hidden behind "+N" stopped: "+N" counts the live ones only, and
// the stopped one shows its undo in the "+N" place once none is hidden
const five = [1, 2, 3, 4, 5].map(i => run(i, 60000 * i, 900000, "T" + i));
const r5 = build({ timers: five });
eq(r5.items.map(i => i.kind), ["timer", "timer", "timer", "timer", "more"], "five: +1");
const gone5 = [{ timer: five[4], at: T0 }];
const a5 = build({ timers: five.slice(0, 4), prev: r5.order, removed: gone5, now: T0 + 1000 });
eq(a5.items.map(i => i.kind + ":" + i.timerId), ["timer:1", "timer:2", "timer:3", "timer:4", "stopped:5"], "the 5th stopped: its undo, no +N");
eq(a5.items[4].action, "undo:5", "Enter undoes the hidden one");
const six = [1, 2, 3, 4, 5, 6].map(i => run(i, 60000 * i, 900000, "T" + i));
const r6 = build({ timers: six });
const a6 = build({ timers: six.filter(t => t.id !== 5), prev: r6.order, removed: [{ timer: six[4], at: T0 }], now: T0 + 1000 });
const more6 = a6.items.find(i => i.kind === "more");
eq([more6.name, more6.timerId], ["+1", 6], "+N counts and opens a live timer");
const l5 = build({ timers: five.slice(0, 4), prev: a5.order, removed: gone5, now: T0 + 6000 });
eq(l5.items.map(i => i.kind), ["timer", "timer", "timer", "timer"], "gone after the undo window");

done();
