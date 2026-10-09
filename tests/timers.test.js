// Timers.js tests — run with: gjs tests/timers.test.js (from the plugin root)
// The pure logic TimerDaemon.qml relies on: time left, progress, names,
// the recents ranking and colour slots.
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/timers.test.js", GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/Timers.js");
const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
const T = new Function(src + "; return { remainingOf, progressOf, displayLabel, rankRecents, remember, freeHue, soundFile, RINGS };")();

let failures = 0, count = 0;

function eq(got, expected, what) {
    count++;
    if (JSON.stringify(got) !== JSON.stringify(expected)) {
        failures++;
        print("✗ " + what + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(got));
    }
}

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
eq(T.displayLabel({ label: "pasta", kind: "in" }), "pasta", "its label first");
eq(T.displayLabel({ kind: "at" }), "Alarm", "an unnamed alarm");
eq(T.displayLabel({ kind: "in" }), "Timer", "an unnamed timer");
eq(T.displayLabel(null), "", "nothing for no timer");

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

// Sound setting → file to play
const DIR = "/p/sounds/";
const HG = DIR + "hourglass.ogg";
const OLD = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
eq(T.RINGS.map(r => r.value), ["default", "silt-chime"], "Hourglass is listed first, then Silt Chime");
eq(T.RINGS.map(r => r.label), ["Hourglass", "Silt Chime"], "ring labels");
eq(T.soundFile("", "", "/h", DIR), HG, "empty choice plays Hourglass");
eq(T.soundFile("default", "", "/h", DIR), HG, "'default' plays Hourglass");
eq(T.soundFile(undefined, "", "/h", DIR), HG, "no setting plays Hourglass");
eq(T.soundFile("Alarm clock (default)", "", "/h", DIR), HG, "the label DMS saved by mistake plays the default (P126)");
eq(T.soundFile("silt-chime", "", "/h", DIR), DIR + "silt-chime.ogg", "Silt Chime plays its file");
eq(T.soundFile(OLD, "", "/h", DIR), OLD, "the old default, saved as a path, keeps playing");
eq(T.soundFile("/usr/share/sounds/x/bell.oga", "", "/h", DIR), "/usr/share/sounds/x/bell.oga", "a full path plays as is");
eq(T.soundFile("custom", "~/Music/a.mp3", "/h", DIR), "/h/Music/a.mp3", "custom expands ~/");
eq(T.soundFile("custom", " file:///tmp/a.ogg ", "/h", DIR), "/tmp/a.ogg", "custom drops file:// and spaces");
eq(T.soundFile("custom", "", "/h", DIR), HG, "custom without a file plays Hourglass");
eq(T.soundFile("custom", "alarm.mp3", "/h", DIR), HG, "custom needs a full path");
eq(T.soundFile("nonsense", "", "/h", DIR), HG, "an unknown choice plays Hourglass");
eq(T.RINGS.every(r => /^[a-z-]+\.ogg$/.test(r.file)), true, "ring files are plain names");

print(failures === 0 ? "✓ " + count + " tests passed" : "\n" + failures + " / " + count + " failed");
imports.system.exit(failures === 0 ? 0 : 1);
