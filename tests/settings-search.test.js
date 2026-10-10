// Search.js tests — run with: gjs -m tests/settings-search.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const Se = load("components/settings/Search.js");
const Sec = load("components/settings/Sections.js");

const keys = q => Se.find(q).map(r => r.key);
const first = q => keys(q)[0];

// Every visible setting is found by its English name, a French synonym and one typo
const french = { noTrigger: "détection", trigger: "déclencheur", hourglassStyle: "sablier", sound: "sonnerie", customSound: "fichier", volume: "niveau", rampUp: "progressif", ringDuration: "durée", tick: "compte à rebours", notify: "notifier", respectDnd: "silence" };
for (const s of Sec.visibleSettings()) {
    eq(keys(s.label).includes(s.key), true, "English name finds " + s.key);
    eq(keys(french[s.key]).includes(s.key), true, "French synonym finds " + s.key);
}
eq(first("hourglas"), "hourglassStyle", "prefix");
eq(first("hourglasss"), "hourglassStyle", "one typo (letter too many)");
eq(first("volune"), "volume", "one typo (wrong letter, 6 letters)");
eq(first("notificaton"), "notify", "one typo (letter missing)");
eq(first("ÉCRAN sablier"), undefined, "AND: every word must match");

// Result shape
const r = Se.find("sablier")[0];
eq([r.key, r.section, r.matched], ["hourglassStyle", "appearance", "word"], "key, section and matched place");
eq(Se.find("volume")[0].matched, "label", "matched label");
eq(Se.find("pulsing")[0].matched, "help", "matched help");
eq(Se.find("loud")[0].key, "volume", "synonym");
eq(Se.find("volume")[0].label, [[0, 6]], "label range for the highlight");

// Hidden (pending) settings are not searchable; empty and no-result
eq(keys("snooze"), [], "pending setting not found");
eq([keys(""), keys("   "), keys(null), keys("zzzzqq")], [[], [], [], []], "empty, blank, bad and no result");
eq(Se.find("a".repeat(500)), [], "very long query is cut, no crash");

// Ranking: a label hit beats a help hit
eq(first("sound"), "sound", "label ranks first");
done();
