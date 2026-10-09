// Preview.js tests — run with: gjs tests/preview.test.js (from the plugin root)
// The one-line preview the launcher shows before Enter.
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/preview.test.js", GLib.get_current_dir())));
const read = f => new TextDecoder().decode(GLib.file_get_contents(dir + "/" + f)[1]);
// Preview.js imports TimeParser.js through the QML « .import »; here the
// parser is loaded the same way as in the other tests and handed in as TP.
const parserSrc = read("TimeParser.js").replace(".pragma library", "");
const TP = new Function(parserSrc + "; return { formatTimeOfDay, isTomorrow, formatHuman, formatRelative };")();
const src = read("Preview.js").split("\n").filter(l => !/^\.(pragma|import)/.test(l)).join("\n");
const P = new Function("TP", src + "; return { previewLine, ringsLine, hintOf };")(TP);

let failures = 0, count = 0;
function eq(got, expected, what) {
    count++;
    if (JSON.stringify(got) !== JSON.stringify(expected)) {
        failures++;
        print("✗ " + what + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(got));
    }
}

// Local time 12:30 on a fixed day, so « ends » is stable in any timezone.
const now = new Date(2026, 9, 9, 12, 30, 0).getTime();
const MIN = 60000;
const at = (h, m, dayShift) => new Date(2026, 9, 9 + (dayShift || 0), h, m, 0).getTime();

eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: "Pasta", count: 1 }, now, true), "Pasta · 12 min · ends 12:42", "labelled duration");
eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: "", count: 1 }, now, true), "Timer · 12 min · ends 12:42", "label-less duration");
eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: "Eggs", count: 3 }, now, true), "Eggs · 3 × 12 min · ends 12:42", "several at once");
eq(P.previewLine({ kind: "duration", ms: 90 * MIN, label: "", count: 1 }, now, false), "Timer · 1 h 30 · ends 2:00 PM", "12-hour clock");
eq(P.previewLine({ kind: "at", at: at(7, 0, 1), ms: at(7, 0, 1) - now, label: "Wake up" }, now, true), "Wake up · at 07:00 tomorrow", "alarm tomorrow");
eq(P.previewLine({ kind: "at", at: at(18, 0), ms: at(18, 0) - now, label: "" }, now, true), "Alarm · at 18:00", "label-less alarm today");

eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: "pasta", count: 1 }, now, true), "Pasta · 12 min · ends 12:42", "label gets a capital");
eq(P.ringsLine({ kind: "duration", ms: 12 * MIN, label: "", count: 1 }, now, true), "Rings at 12:42", "rings at");
eq(P.ringsLine({ kind: "duration", ms: 12 * MIN, count: 25, capped: true }, now, true), "Rings at 12:42 · at most 20 at once", "capped count");
eq(P.ringsLine({ kind: "at", at: at(18, 0), ms: at(18, 0) - now }, now, true), "Rings in 5 h 30", "rings in");

eq(P.hintOf(Object.assign([], { hint: "Unknown word" })), "Unknown word", "parser hint");
eq(P.hintOf([]), "", "no hint");
eq(P.hintOf(null), "", "null results");

print(failures === 0 ? "preview tests: " + count + " ok" : failures + " of " + count + " failed");
imports.system.exit(failures === 0 ? 0 : 1);
