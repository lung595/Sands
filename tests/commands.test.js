// Commands.js tests — run with: gjs tests/commands.test.js (from the plugin root)
// Launcher commands on running timers: what was asked (parseCommand), on
// which timer (resolveTarget), and the line shown before Enter
// (previewCommand), in English and French.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const C = load("Commands.js");

const MIN = 60000, S = 1000;
// Local 18:42:00 on a fixed day, so « ends 18:47 » is stable in any timezone
const NOW = new Date(2026, 10, 20, 18, 42, 0, 0).getTime();

// Only the fields a case cares about
function pick(it, keys) {
    if (!it)
        return null;
    const out = {};
    for (const k of keys)
        out[k] = it[k];
    return out;
}
const ALL = ["kind", "delta", "name", "newName", "minutes"];
function cmd(input, expected) {
    eq(pick(C.parseCommand(input, { now: NOW }), ALL), expected, "parseCommand " + JSON.stringify(input));
}
const it = (kind, more) => Object.assign({ kind, delta: 0, name: "", newName: "", minutes: 0 }, more || {});

// The examples of the plan
cmd("timer +5", it("adjust", { delta: 5 * MIN }));
cmd("timer -2 pâtes", it("adjust", { delta: -2 * MIN, name: "pâtes" }));
cmd("pause pâtes", it("pause", { name: "pâtes" }));
cmd("reprendre", it("resume"));
cmd("snooze 10", it("snooze", { minutes: 10 }));
cmd("renomme pâtes en riz", it("rename", { name: "pâtes", newName: "riz" }));
cmd("rename tea to infusion", it("rename", { name: "tea", newName: "infusion" }));
cmd("thé = infusion", it("rename", { name: "thé", newName: "infusion" }));

// More ways to say them
cmd("minuteur +1h30", it("adjust", { delta: 90 * MIN }));
cmd("+30s", it("adjust", { delta: 30 * S }));
cmd("-2 pâtes", it("adjust", { delta: -2 * MIN, name: "pâtes" }));
cmd("pâtes +5", it("adjust", { delta: 5 * MIN, name: "pâtes" }));
cmd("timer + 5 min tea", it("adjust", { delta: 5 * MIN, name: "tea" }));
cmd("pause", it("pause"));
cmd("PAUSE les Pâtes !", it("pause", { name: "Pâtes" }));
cmd("mets en pause le thé", it("pause", { name: "thé" }));
cmd("resume tea", it("resume", { name: "tea" }));
cmd("reprends les pates", it("resume", { name: "pates" }));
cmd("snooze", it("snooze"));
cmd("snooze 10 min pâtes", it("snooze", { minutes: 10, name: "pâtes" }));
cmd("renomme en riz", it("rename", { newName: "riz" }));
cmd("rename to infusion 🍵", it("rename", { newName: "infusion" }));
cmd("renommer Pâtes en Riz au lait", it("rename", { name: "Pâtes", newName: "Riz au lait" }));
cmd("tea = green tea", it("rename", { name: "tea", newName: "green tea" }));

// Not commands: new timers, calculations, anything else
cmd("pause café 15 min", null);
cmd("pause 5 min", null);
cmd("= 2+2", null);
cmd("2+2", null);
cmd("2 = 2", null);
cmd("tea = 🍵", null);
cmd("c++ 5", null);
cmd("pasta 12", null);
cmd("timer 20 min", null);
cmd("firefox", null);
cmd("snooze 500", null);
cmd("timer +5 at 7pm", null);
cmd("rename tea", null);
cmd("", null);
cmd("pause " + "x".repeat(300), null);

// The language of the words, when only one pack has them
eq(C.parseCommand("reprendre").lang, "fr", "lang of reprendre");
eq(C.parseCommand("resume").lang, "en", "lang of resume");
eq(C.parseCommand("renomme a en b").lang, "fr", "lang of renomme");
eq(C.parseCommand("rename a to b").lang, "en", "lang of rename");
eq(C.parseCommand("minuteur +5").lang, "fr", "lang of minuteur");
eq(C.parseCommand("pause").lang, "", "pause is both");
eq(C.parseCommand("timer +5").lang, "", "timer is both");

// Targets
const pasta = { id: 1, label: "Pâtes", kind: "duration", state: "running", endAt: NOW + 5 * MIN, total: 10 * MIN, remaining: 0, finishedAt: 0 };
const tea = { id: 2, label: "Green tea 🍵", kind: "duration", state: "running", endAt: NOW + 2 * MIN, total: 4 * MIN, remaining: 0, finishedAt: 0 };
const bread = { id: 3, label: "Bread", kind: "duration", state: "paused", endAt: 0, total: 30 * MIN, remaining: 20 * MIN, finishedAt: 0 };
const alarm = { id: 4, label: "", kind: "at", state: "ringing", endAt: NOW - 3 * S, total: H(1), remaining: 0, finishedAt: NOW - 3 * S };
function H(n) {
    return n * 3600000;
}
const timers = [pasta, tea, bread, alarm];
const target = (input, list) => (C.resolveTarget(C.parseCommand(input), list || timers, NOW) || {}).id;

// No name: the nearest the command applies to, the ringing one first
eq(target("timer +5"), 4, "no name: the ringing one");
eq(target("timer +5", [pasta, tea, bread]), 2, "no name, nothing ringing: the one ending first");
eq(target("pause"), 2, "pause: the running one ending first");
eq(target("reprendre"), 3, "resume: a paused one");
eq(target("snooze 10"), 4, "snooze: the ringing one");
eq(target("snooze", [pasta, tea]), undefined, "snooze with nothing ringing: none");
eq(target("reprendre", [pasta]), undefined, "resume with nothing paused: none");
eq(target("thé = infusion", []), undefined, "no timer at all: none");
// A name: that one, whatever is nearer; accents, case and emoji do not count
eq(target("timer -2 pâtes"), 1, "named");
eq(target("timer -2 PATES"), 1, "named, no accents, capitals");
eq(target("pause green tea"), 2, "named, emoji in the timer's name");
eq(target("pause green"), 2, "named by the start of the name");
eq(target("pause tea"), 2, "named by a part of the name");
eq(target("reprendre bread"), 3, "resume named");
eq(target("pause bread"), undefined, "pause of a paused timer: none");
eq(target("pause riz"), undefined, "unknown name: none");
eq(target("renomme pâtes en riz"), 1, "rename named");
eq(target("rename alarm to wake up"), 4, "a timer without a label answers to its kind");

// Preview before Enter
const show = (input, list, options) => {
    const intent = C.parseCommand(input, { now: NOW });
    const p = C.previewCommand(intent, C.resolveTarget(intent, list || timers, NOW), NOW, options);
    return p ? p.text : null;
};
eq(show("timer +5 pâtes", null, { lang: "fr" }), "+5 min à Pâtes (finit à 18:52)", "adjust in French");
eq(show("timer +5 pâtes"), "+5 min to Pâtes (ends 18:52)", "words of both languages, no interface language: English");
eq(show("minuteur +5 pâtes", null, { lang: "en" }), "+5 min to Pâtes (ends 18:52)", "the interface language wins over the words");
eq(show("timer +5", [{ id: 5, label: "Pasta", kind: "duration", state: "running", endAt: NOW + 5 * MIN, total: 5 * MIN, remaining: 0, finishedAt: 0 }], { lang: "en" }),
    "+5 min to Pasta (ends 18:52)", "the plan's English example");
eq(show("minuteur +5", [{ id: 5, label: "Pâtes", kind: "duration", state: "running", endAt: NOW, total: 5 * MIN, remaining: 0, finishedAt: 0 }]),
    "+5 min à Pâtes (finit à 18:47)", "the plan's French example");
eq(show("timer +5 pâtes", null, { lang: "fr_FR" }), "+5 min à Pâtes (finit à 18:52)", "a locale name sets the language");
eq(show("timer +5 pâtes", null, { lang: "de_DE" }), "+5 min to Pâtes (ends 18:52)", "an unknown language gives English");
eq(show("timer +5 pâtes", null, { lang: "en", use24: false }), "+5 min to Pâtes (ends 6:52 PM)", "12 h clock");
// The 10 s floor: -10 min on 5 min left ends 10 s from now, never at once
eq(show("timer -10 pâtes", null, { lang: "fr" }), "−10 min à Pâtes (finit à 18:42)", "floor shown");
{
    const p = C.previewCommand(C.parseCommand("timer -10 pâtes"), pasta, NOW, {});
    eq([p.at - NOW, p.changed, p.icon], [10 * S, true, "more_time"], "floor: 10 s left");
    const again = C.previewCommand(C.parseCommand("timer -1"), Object.assign({}, pasta, { endAt: NOW + 10 * S }), NOW, {});
    eq(again.changed, false, "already at the floor: nothing to do");
}
// A ringing timer restarts for the amount
eq(show("timer +5", null, { lang: "en" }), "+5 min to Alarm (ends 18:47)", "ringing alarm restarts");
eq(show("timer +5", null, { lang: "fr" }), "+5 min à Alarme (finit à 18:47)", "ringing alarm restarts, French");
eq(show("pause pâtes"), "Pause Pâtes", "pause");
eq(show("reprendre"), "Reprendre Bread (finit à 19:02)", "resume");
eq(show("resume bread"), "Resume Bread (ends 19:02)", "resume, English");
eq(show("snooze 10", null, { lang: "fr" }), "Snooze Alarme 10 min (sonne à 18:52)", "snooze");
eq(show("snooze", null, { lang: "en", snoozeMinutes: 1 }), "Snooze Alarm 1 min (rings 18:43)", "snooze default from the settings");
eq(show("snooze", null, { lang: "en" }), "Snooze Alarm 5 min (rings 18:47)", "snooze default");
eq(show("renomme pâtes en riz"), "Pâtes → riz", "rename");
eq(show("thé = infusion", [Object.assign({}, tea, { label: "Thé" })], { lang: "en" }), "Thé → infusion", "rename with =");
eq(show("pause riz"), null, "no target: nothing shown");
eq(C.previewCommand(null, pasta, NOW, {}), null, "no intent: nothing shown");
eq(C.previewCommand(C.parseCommand("pause"), pasta, NOW, {}).icon, "pause", "icon is a Material Symbols name");

done();
