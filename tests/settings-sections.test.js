// Sections.js tests — run with: gjs -m tests/settings-sections.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const GLib = imports.gi.GLib;
const S = load("components/settings/Sections.js");
const L = load("components/settings/SectionLogos.js");

const root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
// The rows live in the section files next to the page
const qml = ["Timers", "Appearance", "Alerts"].map(n => new TextDecoder().decode(GLib.file_get_contents(root + "/components/settings/" + n + "Section.qml")[1])).join("\n");
const keys = S.SETTINGS.map(s => s.key);

// Every key of the settings page is in the table, once, with its default
const existing = ["trigger", "noTrigger", "hourglassStyle", "alertKind", "alertScreen", "duneStyle", "duneOverFullscreen", "alertWhen", "sound", "customSound", "volume", "rampUp", "ringDuration", "tick", "notify", "respectDnd"];
for (const k of existing)
    eq(keys.filter(x => x === k).length, 1, "key present once: " + k);
eq(new Set(keys).size, keys.length, "no key is listed twice");
// Defaults are read from the QML page (defaultValue next to each settingKey) so a drift fails here
const qmlDefault = k => {
    const block = qml.split(/settingKey:/).find(x => x.trim().startsWith('"' + k + '"'));
    const m = block && block.match(/defaultValue:\s*([^\n]+)/);
    return m ? JSON.parse(m[1].trim()) : undefined;
};
const defaults = Object.fromEntries(existing.map(k => [k, qmlDefault(k)]));
for (const k of existing)
    eq(S.SETTINGS.find(s => s.key === k).default, defaults[k], "default unchanged: " + k);

// Label, level and cost live twice (table and row; the table help is a shorter search line, so it is not compared): a drift fails here
const qmlField = (k, f) => {
    const block = qml.split(/settingKey:/).find(x => x.trim().startsWith('"' + k + '"'));
    const m = block && block.match(new RegExp("\\n\\s*" + f + ':\\s*"((?:[^"\\\\]|\\\\.)*)"'));
    return m ? m[1] : undefined;
};
for (const k of existing) {
    const t = S.SETTINGS.find(s => s.key === k);
    eq(qmlField(k, "label"), t.label, "label matches the row: " + k);
    eq(qmlField(k, "level") || undefined, t.level, "level matches the row: " + k);
    eq(qmlField(k, "cost") || undefined, t.cost, "cost matches the row: " + k);
}

// A settingKey added to the QML without a table entry fails here
const inQml = [...qml.matchAll(/settingKey:\s*"(\w+)"/g)].map(m => m[1]);
eq(inQml.length > 0, true, "the QML page has setting keys");
eq(inQml.filter(k => !keys.includes(k)), [], "every QML settingKey is in the table");

// Decided on NAK-395 / D423: present and held back until merged
for (const k of ["lookPreset", "snooze", "noticeBefore"])
    eq(S.SETTINGS.find(s => s.key === k).pending, true, "pending: " + k);
eq(S.visibleSettings().some(s => s.pending), false, "pending settings are not visible");

// Every setting belongs to a known section, has words
const ids = S.SECTIONS.map(s => s.id);
eq(S.SETTINGS.filter(s => !ids.includes(s.section)).map(s => s.key), [], "every setting has a known section");
eq(S.SETTINGS.filter(s => !s.words.length || !s.help || !s.label).map(s => s.key), [], "label, help and words are filled");

// Section order and the hidden rule
eq(ids, ["timers", "focus", "appearance", "effects", "bar", "desktop", "alerts", "advanced", "help"], "section order");
eq(S.visibleSections().map(s => s.id), ["timers", "appearance", "alerts", "advanced", "help"], "empty sections are hidden, order kept");

// Helpers
eq(S.sectionOf("volume"), "alerts", "section of a key");
eq(S.sectionOf("nope"), "", "unknown key has no section");
eq(S.settingsOf("timers").map(s => s.key), ["noTrigger", "trigger", "endActions"], "settings of a section, pending held back");
eq([S.previousSection("timers"), S.nextSection("timers")], ["timers", "appearance"], "start of the list");
eq([S.previousSection("help"), S.nextSection("help")], ["advanced", "help"], "end of the list");
eq(S.nextSection("bogus"), "timers", "unknown section starts at the first");
eq(S.costly("light").map(s => s.key), ["tick"], "costly settings by level");
eq([S.costly("high"), S.costly("some")], [[], []], "no costly setting at the other levels");
eq(S.SETTINGS.filter(s => s.level && (!s.cost || !S.LEVELS.includes(s.level))).length, 0, "a level always comes with a cost note");
// Every section of the rail has its drawn logo
for (const sec of S.SECTIONS)
    eq(L.pathFor(sec.id) !== "", true, "logo drawn for " + sec.id);
eq(L.pathFor("bogus"), "", "unknown id draws nothing");

// Visual alert rows (NAK-681, NAK-663): visible, filed under Alerts & sounds, with
// the keys the daemon reads (RingAlert.qml) and the defaults of the pure rules
const P = load("components/alert/AlertPolicy.js");
const D = load("components/alert/DuneStyles.js");
const alertKeys = ["alertKind", "alertScreen", "duneStyle", "duneOverFullscreen", "alertWhen", "testAlarm"];
eq(S.settingsOf("alerts").map(s => s.key).slice(0, 6), alertKeys, "the visual alert rows come first, in page order");
const ring = new TextDecoder().decode(GLib.file_get_contents(root + "/components/alert/RingAlert.qml")[1]);
const read = [...ring.matchAll(/_read\("(\w+)"/g)].map(m => m[1]);
eq(["alertKind", "alertScreen", "duneStyle", "duneOverFullscreen", "alertWhen"].filter(k => !read.includes(k)), [], "every saved alert key is read by the daemon");
eq(read.filter(k => !keys.includes(k)), [], "the daemon reads no alert key the page does not have");
const def = k => S.SETTINGS.find(s => s.key === k).default;
eq([def("alertKind"), def("alertWhen"), def("duneStyle"), def("duneOverFullscreen")], [P.DEFAULT_KIND, P.DEFAULT_WHEN, D.DEFAULT, false], "defaults are the ones of AlertPolicy and DuneStyles");
eq(def("alertWhen"), "always", "the alert shows every time by default (owner's choice)");
// The screen of the alert: all by default, the same word as the pure rule, and the
// choice reaches the dune and the halo, for a ring and for a test
eq([def("alertScreen"), P.DEFAULT_SCREEN], ["all", "all"], "the alert shows on every screen by default, as before the setting");
const src = n => new TextDecoder().decode(GLib.file_get_contents(root + "/components/alert/" + n)[1]);
for (const n of ["DuneWindows.qml", "HaloWindows.qml"])
    eq(/model: Policy\.pickScreens\(Quickshell\.screens, root\.screenNames\)/.test(src(n)), true, n + " draws on the chosen screens only");
eq((ring.match(/screenNames: root\._screenNames/g) || []).length, 2, "the wiring hands the chosen screens to the halo host and to the dune");
eq(/screenNames: root\.screenNames/.test(src("DuneAlert.qml")), true, "the host hands them to the halo");
eq(/property: "screenNames"/.test(src("HaloScene.qml")), true, "the halo scene hands them to its windows");
eq((ring.match(/_aim\(\);/g) || []).length, 2, "the screens are chosen at the ring point and at a test");
eq(keys.includes("visualAlert"), false, "the pending placeholder row is replaced");
eq(/DuneAlert\s*\{/.test(qml), false, "the page holds no alert host of its own: the test goes through the daemon");
eq(/daemon\.testAlert\(\)/.test(qml), true, "Test the alarm asks the daemon");
done();
