// Sections.js tests — run with: gjs -m tests/settings-sections.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const GLib = imports.gi.GLib;
const S = load("components/settings/Sections.js");

const root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const qml = new TextDecoder().decode(GLib.file_get_contents(root + "/TimerSettings.qml")[1]);
const keys = S.SETTINGS.map(s => s.key);

// Every key of the settings page is in the table, once, with its default
const existing = ["trigger", "noTrigger", "hourglassStyle", "sound", "customSound", "volume", "rampUp", "ringDuration", "tick", "notify", "respectDnd"];
for (const k of existing)
    eq(keys.filter(x => x === k).length, 1, "key present once: " + k);
eq(new Set(keys).size, keys.length, "no key is listed twice");
// Defaults are read from the QML page (defaultValue next to each settingKey) so a drift fails here
const qmlDefault = k => {
    const m = qml.match(new RegExp('settingKey:\\s*"' + k + '"[^}]*?defaultValue:\\s*([^\\n]+)'));
    return m ? JSON.parse(m[1].trim().replace(/,$/, "")) : undefined;
};
const defaults = Object.fromEntries(existing.map(k => [k, qmlDefault(k)]));
for (const k of existing)
    eq(S.SETTINGS.find(s => s.key === k).default, defaults[k], "default unchanged: " + k);

// A settingKey added to the QML without a table entry fails here
const inQml = [...qml.matchAll(/settingKey:\s*"(\w+)"/g)].map(m => m[1]);
eq(inQml.length > 0, true, "the QML page has setting keys");
eq(inQml.filter(k => !keys.includes(k)), [], "every QML settingKey is in the table");

// Decided on NAK-395 / D423: present and held back until merged
for (const k of ["lookPreset", "visualAlert", "snooze", "noticeBefore"])
    eq(S.SETTINGS.find(s => s.key === k).pending, true, "pending: " + k);
eq(S.visibleSettings().some(s => s.pending), false, "pending settings are not visible");

// Every setting belongs to a known section, has words
const ids = S.SECTIONS.map(s => s.id);
eq(S.SETTINGS.filter(s => !ids.includes(s.section)).map(s => s.key), [], "every setting has a known section");
eq(S.SETTINGS.filter(s => !s.words.length || !s.help || !s.label).map(s => s.key), [], "label, help and words are filled");

// Section order and the hidden rule
eq(ids, ["timers", "focus", "appearance", "effects", "bar", "desktop", "alerts", "advanced", "help"], "section order");
eq(S.visibleSections().map(s => s.id), ["timers", "appearance", "alerts"], "empty sections are hidden, order kept");

// Helpers
eq(S.sectionOf("volume"), "alerts", "section of a key");
eq(S.sectionOf("nope"), "", "unknown key has no section");
eq(S.settingsOf("timers").map(s => s.key), ["noTrigger", "trigger"], "settings of a section, pending held back");
eq([S.previousSection("timers"), S.nextSection("timers")], ["timers", "appearance"], "start of the list");
eq([S.previousSection("alerts"), S.nextSection("alerts")], ["appearance", "alerts"], "end of the list");
eq(S.nextSection("bogus"), "timers", "unknown section starts at the first");
eq(S.costly("some").map(s => s.key), ["tick"], "costly settings by level");
eq([S.costly("high"), S.costly("light")], [[], []], "no costly setting at the other levels");
eq(S.SETTINGS.filter(s => s.level && (!s.cost || !S.LEVELS.includes(s.level))).length, 0, "a level always comes with a cost note");
done();
