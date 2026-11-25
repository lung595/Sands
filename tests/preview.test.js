// Preview.js tests — run with: gjs tests/preview.test.js (from the plugin root)
// The one-line preview the launcher shows before Enter.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const P = load("Preview.js");

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
eq(P.title("pasta"), "Pasta", "title adds a capital");
eq(P.title(""), "", "title keeps an empty label empty");
// The label the action carries must read exactly like the preview's.
eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: P.title("pasta"), count: 1 }, now, true), P.previewLine({ kind: "duration", ms: 12 * MIN, label: "pasta", count: 1 }, now, true), "action label matches preview");
eq(P.ringsLine({ kind: "duration", ms: 12 * MIN, label: "", count: 1 }, now, true), "Rings at 12:42", "rings at");
eq(P.ringsLine({ kind: "duration", ms: 12 * MIN, count: 25, capped: true }, now, true), "Rings at 12:42 · at most 20 at once", "capped count");
eq(P.ringsLine({ kind: "at", at: at(18, 0), ms: at(18, 0) - now }, now, true), "Rings in 5 h 30", "rings in");

// French when the interface language is French (a locale name works too)
eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: "pâtes", count: 1 }, now, true, "fr"), "Pâtes · 12 min · finit à 12:42", "French duration");
eq(P.previewLine({ kind: "duration", ms: 12 * MIN, label: "", count: 2 }, now, true, "fr_FR"), "Minuteur · 2 × 12 min · finit à 12:42", "French label-less duration");
eq(P.previewLine({ kind: "at", at: at(7, 0, 1), ms: at(7, 0, 1) - now, label: "" }, now, true, "fr"), "Alarme · à 07:00 demain", "French alarm tomorrow");
eq(P.ringsLine({ kind: "duration", ms: 12 * MIN, count: 25, capped: true }, now, true, "fr"), "Sonne à 12:42 · 20 au plus à la fois", "French capped count");
eq(P.ringsLine({ kind: "at", at: at(18, 0), ms: at(18, 0) - now }, now, true, "fr"), "Sonne dans 5 h 30", "French rings in");
eq(P.ringsLine({ kind: "duration", ms: 12 * MIN, count: 1 }, now, true, "de_DE"), "Rings at 12:42", "another language falls back to English");

eq(P.hintOf(Object.assign([], { hint: "Unknown word" })), "Unknown word", "parser hint");
eq(P.hintOf([]), "", "no hint");
eq(P.hintOf(null), "", "null results");

done();
