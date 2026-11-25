// Search.js tests — run with: gjs -m tests/settings-search.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const Se = load("components/settings/Search.js");
const Sec = load("components/settings/Sections.js");

const keys = q => Se.find(q).map(r => r.key);
const first = q => keys(q)[0];

// Every visible setting is found by its English name, a French synonym and one typo
const french = { wakeRingMinutes: "veille", launcherSection: "lanceur", launcherSectionDuringSearch: "pendant", launcherSectionFavourites: "favoris", launcherAnimate: "animer", noTrigger: "détection", trigger: "déclencheur", hourglassStyle: "sablier", sound: "sonnerie", customSound: "fichier", volume: "niveau", rampUp: "progressif", ringDuration: "durée", tick: "compte à rebours", notify: "notifier", respectDnd: "silence", examples: "exemple", eraseHistory: "effacer", alertKind: "alerte", duneStyle: "vague", duneOverFullscreen: "plein écran", alertWhen: "toujours", testAlarm: "tester", alertScreen: "écran", report: "rapport", gettingStarted: "tutoriel" };
// One typo each (a letter swapped, dropped or added) in a word of the label or a synonym
const typo = { wakeRingMinutes: "suspnd", launcherSection: "launchr", launcherSectionDuringSearch: "serching", launcherSectionFavourites: "favourits", launcherAnimate: "animte", noTrigger: "detectoin", trigger: "triger", hourglassStyle: "hourglas", sound: "sonud", customSound: "custm", volume: "volmue", rampUp: "progresif", ringDuration: "duraton", tick: "countdwn", notify: "notificaton", respectDnd: "respct", examples: "exampls", eraseHistory: "histry", alertKind: "visaul", duneStyle: "grians", duneOverFullscreen: "fulscreen", alertWhen: "alwayz", testAlarm: "alamr", alertScreen: "monitr", report: "diagnostc", gettingStarted: "tutorail" };
for (const s of Sec.visibleSettings()) {
    eq(keys(s.label).includes(s.key), true, "English name finds " + s.key);
    eq(keys(french[s.key]).includes(s.key), true, "French synonym finds " + s.key);
    eq(keys(typo[s.key]).includes(s.key), true, "one typo finds " + s.key);
}
eq(first("hourglas"), "hourglassStyle", "prefix");
// The "finished during sleep" row, found in both languages
eq(first("veille"), "wakeRingMinutes", "veille finds the sleep row");
eq(first("sleep"), "wakeRingMinutes", "sleep finds the sleep row");
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
eq(Se.find("sablier")[0].text, "sablier", "matched text of a synonym");
eq(Se.find("volume")[0].text, "Volume", "matched text of a label");
eq(Se.find("pulsing")[0].text, "pulsing", "matched text of help");
eq(Se.find("volume")[0].label, [[0, 6]], "label range for the highlight");

// Hidden (pending) settings are not searchable; empty and no-result
eq(keys("snooze"), [], "pending setting not found");
eq([keys(""), keys("   "), keys(null), keys("zzzzqq")], [[], [], [], []], "empty, blank, bad and no result");
eq(Se.find("a".repeat(500)), [], "very long query is cut, no crash");

// The visual alert rows are found by what the user would type
eq(first("visual alert"), "alertKind", "the kind row by its name");
eq(keys("halo").includes("alertKind"), true, "the kind row by one of its cards");
eq(first("test the alarm"), "testAlarm", "the test button by its name");
eq(keys("full screen").includes("duneOverFullscreen"), true, "the full-screen switch in two words");
eq(keys("chaque fois").includes("alertWhen"), true, "the moment row in French");
// The screen row is found in both languages
for (const q of ["screen", "monitor", "écran", "ecran", "moniteur", "display", "show on", "active screen", "all screens", "tous les écrans"])
    eq(keys(q).includes("alertScreen"), true, "the screen row by \"" + q + "\"");
eq(first("show on"), "alertScreen", "the screen row by its name");
eq(first("monitor"), "alertScreen", "the screen row first for monitor");
eq(Se.find("monitor")[0].section, "alerts", "the screen row is under Alerts & sounds");
eq(keys("visualAlert"), [], "the placeholder key of the pending row is gone");
// The end actions are gone (1.7.0): no row answers for them any more
eq(Sec.SETTINGS.some(s => s.key === "endActions"), false, "no end-actions row");
for (const q of ["end actions", "power off", "shutdown", "film", "commande", "éteindre", "mots"])
    eq(keys(q).includes("endActions"), false, "nothing for \"" + q + "\"");

// Ranking: a label hit beats a help hit
eq(first("sound"), "sound", "label ranks first");
// "add widget" (and its French) lands on Getting started first
eq(first("add widget"), "gettingStarted", "add widget finds Getting started");
eq(first("ajouter barre"), "gettingStarted", "ajouter barre finds Getting started");
// The launcher row settings, by what the user would type
eq(first("super space"), "launcherSection", "super space finds the launcher row");
eq(Se.find("animate")[0].section, "launcher", "animate lands in the Launcher section");
eq(keys("sabliers").includes("launcherAnimate"), true, "sabliers also finds the animation switch");
done();
