// TimeFormat.js tests — run with: gjs tests/time-format.test.js (from the plugin root)
// Countdowns, durations and clock times, the 12/24 h choice passed by the
// caller, the temporary re-export from TimeParser.js and the single
// normalize shared by the two parsers.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, read, eq, done } = imports.harness;
const TF = load("TimeFormat.js");
const TP = load("TimeParser.js");
const P = load("Plans.js");
const S = 1000, MIN = 60000, H = 3600000;
const at = (h, m) => new Date(2026, 10, 20, h, m).getTime();

// Countdown and durations
eq(TF.formatClock(20 * MIN), "20:00", "countdown start");
eq(TF.formatClock(20 * MIN - 1), "20:00", "rounded up");
eq(TF.formatClock(H + 2 * MIN + 3 * S), "1:02:03", "with hours");
eq(TF.formatClock(-12 * S - 300), "−0:12", "elapsed since the end");
eq(TF.formatHuman(90 * MIN), "1 h 30", "human h + min");
eq(TF.formatHuman(90 * S), "1 min 30 s", "human min + s");
eq(TF.formatRelative(2 * H + 16 * MIN), "2 h 16", "relative");
eq(TF.formatRelative(20 * S), "20 s", "relative under a minute");
eq(TF.widthTemplate("1:02:59"), "0:00:00", "width template");
eq(TF.pad(7), "07", "pad");

// 12/24 h: the DMS choice, passed as an argument
eq(TF.formatTimeOfDay(at(18, 42), true), "18:42", "24 h evening");
eq(TF.formatTimeOfDay(at(18, 42), false), "6:42 PM", "12 h evening");
eq(TF.formatTimeOfDay(at(8, 5), true), "08:05", "24 h pads the hour like DMS HH:mm");
eq(TF.formatTimeOfDay(at(8, 5), false), "8:05 AM", "12 h morning, no pad like DMS h:mm AP");
eq(TF.formatTimeOfDay(at(0, 0), false), "12:00 AM", "12 h midnight");
eq(TF.formatTimeOfDay(at(12, 0), false), "12:00 PM", "12 h noon");
eq(TF.formatTimeOfDay(at(0, 0), true), "00:00", "24 h midnight");
eq(TF.formatTimeOfDay(at(18, 42)), "18:42", "no choice given reads as 24 h");
eq(TF.use24h(true), true, "setting true");
eq(TF.use24h(false), false, "setting false");
eq(TF.use24h(undefined), true, "setting not loaded yet: 24 h");
eq(TF.formatTimeOfDay(at(18, 42), TF.use24h(false)), "6:42 PM", "helper feeds the formatter");
eq(TF.isTomorrow(at(23, 0) + 2 * H, at(23, 0)), true, "past midnight is tomorrow");
eq(TF.isTomorrow(at(18, 42), at(9, 0)), false, "same day");
eq(TF.isTomorrow(at(23, 0) + 26 * H, at(23, 0)), false, "two days later is not tomorrow");
eq(TF.isTomorrow(new Date(2026, 11, 20, 9, 0).getTime(), at(9, 0)), false, "same date next month is not tomorrow");
eq(TF.isTomorrow(new Date(2026, 11, 1, 8, 0).getTime(), new Date(2026, 10, 30, 22, 0).getTime()), true, "month rollover is tomorrow");

// TimeParser.js re-exports every formatter unchanged (temporary)
for (const name of ["pad", "formatClock", "formatHuman", "formatRelative", "formatTimeOfDay", "isTomorrow", "widthTemplate"])
    eq(typeof TP[name], "function", "TimeParser re-exports " + name);
eq(TP.formatTimeOfDay(at(18, 42), false), TF.formatTimeOfDay(at(18, 42), false), "re-export gives the same text");
for (const m of read("TimeParser.js").matchAll(/^function (pad|format\w+|isTomorrow|widthTemplate)\(([^)]*)\) \{(.*)\}$/gm))
    eq(m[3].trim(), "return TimeFormat." + m[1] + "(" + m[2] + ");", "TimeParser." + m[1] + " only hands over to TimeFormat");
eq([...read("TimeParser.js").matchAll(/^function (pad|format\w+|isTomorrow|widthTemplate)\(/gm)].length, 7, "seven one-line re-exports, no formatter body left");

// One normalize: Plans.js uses the parser's
eq(/^function normalize\(/m.test(read("Plans.js")), false, "Plans.js has no normalize of its own");
eq(P.normalize("Pâtes ’Été` É"), TP.normalize("Pâtes ’Été` É"), "same normalize in both parsers");
eq(P.normalize("Pâtes ’Été`"), "pates 'ete'", "lowercase, no accents, straight apostrophes");
eq(P.normalize("Crème brûlée").length, "Crème brûlée".length, "one character in, one out");

done();
