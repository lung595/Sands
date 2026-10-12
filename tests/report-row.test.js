// The "Copy report" row texts and states, and the fixed GitHub address.
// Run: gjs tests/report-row.test.js
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq, done, load } = imports.harness;

const Row = load("components/settings/ReportRow.js");

eq(Row.phaseOf(false, "idle"), "idle", "rest");
eq(Row.phaseOf(true, "idle"), "collecting", "building");
eq(Row.phaseOf(false, "copying"), "collecting", "copying");
eq(Row.phaseOf(false, "copied"), "copied", "copied");
eq(Row.phaseOf(false, "none"), "none", "no tool");

eq(Row.view("idle").button, "Copy report", "rest label");
eq(Row.view("collecting").button, "Collecting…", "collecting label");
eq(Row.view("copied").button, "Copied", "copied label");
eq(Row.view("copied").help, "Report copied. Read it, then paste it in a GitHub issue.", "copied help");
eq(Row.view("copied").markActive, true, "mark turns primary after copied");
eq(Row.view("idle").markActive, false, "mark rests otherwise");
eq(Row.view("none").note.anchor, "report-a-problem", "guide anchor");
eq(Row.view("idle").note, null, "no message at rest");
eq(Row.GITHUB_URL, "https://github.com/lung595/Sands/issues/new/choose", "constant URL");

let text = JSON.stringify([Row.view("idle"), Row.view("copied"), Row.view("none"), Row.view("collecting")]);
eq(Row.view("copied", true).help, "Report copied, and kept in the DMS clipboard history: delete it there once pasted.", "the fallback copy says the history holds it");
eq(Row.view("copied", false).help, Row.view("copied").help, "a sensitive copy keeps the plain words");
eq(Row.view("idle", true).help, Row.HELP, "an old flag changes nothing at rest");
text += JSON.stringify(Row.view("copied", true));
eq(/[\u2013\u2014]/.test(text), false, "no long dash of either width");
done();
