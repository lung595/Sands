// Timers.js tests — run with: gjs tests/timers.test.js (from the plugin root)
// The pure logic TimerDaemon.qml relies on: time left, progress, names,
// the recents ranking, colour slots and emoji-free names.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const T = load("Timers.js");

const DAY = 86400000;

// Time left in each state
eq(T.remainingOf(null, 0), 0, "no timer has nothing left");
eq(T.remainingOf({ state: "running", endAt: 5000 }, 2000), 3000, "running counts down to endAt");
eq(T.remainingOf({ state: "paused", remaining: 700, endAt: 1 }, 99999), 700, "paused keeps what was left");
eq(T.remainingOf({ state: "ringing", finishedAt: 1000 }, 4000), -3000, "ringing counts up since it finished");
eq(T.remainingOf({ state: "ringing" }, 4000), 0, "ringing without a finish time reads 0");

// Progress stays within [0, 1]
eq(T.progressOf({ state: "running", endAt: 1000, total: 1000 }, 0), 1, "just started");
eq(T.progressOf({ state: "running", endAt: 1000, total: 1000 }, 500), 0.5, "half way");
eq(T.progressOf({ state: "running", endAt: 1000, total: 1000 }, 3000), 0, "overdue clamps to 0");
eq(T.progressOf({ state: "running", endAt: 9000, total: 1000 }, 0), 1, "never above 1");
eq(T.progressOf({ state: "running", endAt: 1000, total: 0 }, 0), 0, "a zero total does not divide by zero");

// Names
eq(T.displayLabel({ label: "pasta", kind: "in" }), "Pasta", "its label first, with a capital");
eq(T.displayLabel({ label: "thé vert", kind: "in" }), "Thé vert", "only the first letter, accents kept");
eq(T.displayLabel({ label: "Pâtes", kind: "in" }), "Pâtes", "a capital already there is kept");
eq(T.displayLabel({ kind: "at" }), "Alarm", "an unnamed alarm");
eq(T.displayLabel({ kind: "in" }), "Timer", "an unnamed timer");
eq(T.displayLabel(null), "", "nothing for no timer");
eq(T.savedName({ label: "thé", kind: "in" }), "thé", "the saved name stays as typed");
eq(T.savedName({ kind: "at" }), "Alarm", "an unnamed alarm is saved under its kind");
eq(T.savedName({ kind: "in" }), "Timer", "an unnamed timer too");
eq(T.savedName(null), "", "no saved name for no timer");

// Frecency: often and recently beats often long ago
const now = 100 * DAY;
const ranked = T.rankRecents([
    { ms: 1, label: "old", uses: 10, last: now - 30 * DAY },
    { ms: 2, label: "fresh", uses: 2, last: now - DAY }
], now);
eq(ranked.map(r => r.label), ["fresh", "old"], "yesterday's twice beats last month's ten times");
eq(T.rankRecents([{ ms: 1, uses: 3, last: now }], now).length, 1, "ranking keeps every entry");

// Remembering: same duration and name (any case) is one more use
let rec = T.remember([], 60000, "Tea", now);
eq(rec, [{ ms: 60000, label: "Tea", uses: 1, last: now }], "a first start is added");
rec = T.remember(rec, 60000, "tea", now + 1);
eq(rec.length, 1, "same duration, other case: not a new entry");
eq(rec[0].uses, 2, "…it counts one more use");
eq(rec[0].label, "tea", "…with the latest spelling");
eq(T.remember(rec, 120000, "tea", now).length, 2, "another duration is another entry");
const many = [];
for (let i = 0; i < 20; i++)
    many.push({ ms: i, label: "", uses: 1, last: now - i * DAY });
eq(T.remember(many, 999, "new", now).length, 12, "at most 12 are kept");

// Colour slots
eq(T.freeHue([], 6), 0, "the first slot when nothing runs");
eq(T.freeHue([{ hue: 0 }, { hue: 1 }, { hue: 3 }], 6), 2, "the first free slot");
eq(T.freeHue([0, 1, 2].map(h => ({ hue: h })), 3), 0, "all taken: the next in turn");

// Names without emoji
eq(T.stripEmoji("🍝 pâtes", 60), "pâtes", "an emoji before the name is dropped");
eq(T.stripEmoji("thé 🍵 vert", 60), "thé vert", "one in the middle leaves a single space");
eq(T.stripEmoji("👨‍👩‍👧 famille 👍🏽 ❤️ 🇫🇷 🏴󠁧󠁢󠁳󠁣󠁴󠁿", 60), "famille", "joined, toned, dressed, flag and tag sequences go whole");
eq(T.stripEmoji("étape 1️⃣ ⏰ ⌛", 60), "étape 1", "a keycap keeps its digit, clock symbols go");
eq(T.stripEmoji("Ça & 12 ½ — ok", 60), "Ça & 12 ½ — ok", "accents and punctuation stay");
eq(T.stripEmoji("a\tb\n c", 60), "a b c", "control characters are spaces");
eq(T.stripEmoji("x".repeat(80), 60).length, 60, "capped to the given length");
eq(T.stripEmoji("x".repeat(59) + "𝄞", 60), "x".repeat(59), "never half a surrogate pair");
eq(T.stripEmoji(undefined, 60), "", "nothing is an empty name");
eq(T.fallbackName("fr_FR"), "Minuteur", "French fallback");
eq(T.fallbackName("en_US"), "Timer", "any other language: Timer");
eq(T.cleanName("🍝", 60, "Minuteur"), "Minuteur", "a name that was only an emoji gets the fallback");
eq(T.cleanName("  ", 60, "Timer"), "", "an empty name stays empty");
eq(T.cleanName("🍝 Pâtes", 60, "Timer"), "Pâtes", "a name with letters keeps them");

done();
