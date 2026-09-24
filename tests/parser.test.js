// Tests de TimeParser.js — lancer avec : gjs -m tests/parser.test.js
// (ou : gjs tests/parser.test.js depuis la racine du plugin)
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/parser.test.js", GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/TimeParser.js");
const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
const TP = new Function(src + "; return { parse, formatClock, formatHuman, formatRelative, formatTimeOfDay };")();

// Mercredi 24 sept. 2026, 21:47:00 heure locale
const NOW = new Date(2026, 8, 24, 21, 47, 0, 0).getTime();
const MIN = 60000, H = 3600000, S = 1000;

let failures = 0, count = 0;

function check(input, expected, opts) {
    count++;
    const res = TP.parse(input, NOW, opts);
    const got = res.map(r => r.kind === "at"
        ? { at: new Date(r.at).getHours() + ":" + String(new Date(r.at).getMinutes()).padStart(2, "0"), label: r.label }
        : { ms: r.ms, label: r.label });
    const ok = JSON.stringify(got) === JSON.stringify(expected);
    if (!ok) {
        failures++;
        print("✗ " + JSON.stringify(input) + "\n    attendu : " + JSON.stringify(expected) + "\n    obtenu  : " + JSON.stringify(got));
    }
}

// Durées simples
check("timer 20 min", [{ ms: 20 * MIN, label: "" }]);
check("timer 20min", [{ ms: 20 * MIN, label: "" }]);
check("20 min", [{ ms: 20 * MIN, label: "" }]);
check("20m", [{ ms: 20 * MIN, label: "" }]);
check("minuteur 45s", [{ ms: 45 * S, label: "" }]);
check("timer 90 secondes", [{ ms: 90 * S, label: "" }]);
check("timer 2 heures", [{ ms: 2 * H, label: "" }]);
check("timer 1h", [{ ms: H, label: "" }]);
check("Timer 1H30", [{ ms: 90 * MIN, label: "" }]);
check("timer 1h30", [{ ms: 90 * MIN, label: "" }]);
check("timer 1h 30", [{ ms: 90 * MIN, label: "" }]);
check("timer 1 h 30 min", [{ ms: 90 * MIN, label: "" }]);
check("timer 1h30m20s", [{ ms: 90 * MIN + 20 * S, label: "" }]);
check("timer 5m30", [{ ms: 5 * MIN + 30 * S, label: "" }]);
check("timer 2 heures 5", [{ ms: 2 * H + 5 * MIN, label: "" }]);
check("timer 1.5h", [{ ms: 90 * MIN, label: "" }]);
check("timer 1,5 h", [{ ms: 90 * MIN, label: "" }]);
check("timer 1:30", [{ ms: 90 * S, label: "" }]);
check("timer 1:02:03", [{ ms: H + 2 * MIN + 3 * S, label: "" }]);
check("timer 5", [{ ms: 5 * MIN, label: "" }]);
check("timer 2.5", [{ ms: 150 * S, label: "" }]);
check("5", [], {});
check("5", [{ ms: 5 * MIN, label: "" }], { keyword: true });
check("30 min", [{ ms: 30 * MIN, label: "" }], { keyword: true });

// En toutes lettres
check("timer une demi-heure", [{ ms: 30 * MIN, label: "" }]);
check("minuteur demi heure", [{ ms: 30 * MIN, label: "" }]);
check("timer un quart d'heure", [{ ms: 15 * MIN, label: "" }]);
check("timer trois quarts d’heure", [{ ms: 45 * MIN, label: "" }]);
check("timer une heure et demie", [{ ms: 90 * MIN, label: "" }]);
check("timer 2 heures et quart", [{ ms: 2 * H + 15 * MIN, label: "" }]);
check("timer cinq minutes", [{ ms: 5 * MIN, label: "" }]);
check("timer vingt-cinq minutes", [{ ms: 25 * MIN, label: "" }]);
check("timer dix-sept minutes", [{ ms: 17 * MIN, label: "" }]);
check("timer half an hour", [{ ms: 30 * MIN, label: "" }]);
check("timer an hour and a half", [{ ms: 90 * MIN, label: "" }]);
check("timer a minute", [{ ms: MIN, label: "" }]);
check("timer twenty five minutes", [{ ms: 25 * MIN, label: "" }]);

// Libellés
check("timer 12 min pâtes", [{ ms: 12 * MIN, label: "pâtes" }]);
check("timer pâtes 12 min", [{ ms: 12 * MIN, label: "pâtes" }]);
check("timer pâtes pour 12 min", [{ ms: 12 * MIN, label: "pâtes" }]);
check("25m Sortir le linge", [{ ms: 25 * MIN, label: "Sortir le linge" }]);
check("timer 1h30 four", [{ ms: 90 * MIN, label: "four" }]);
check("timer 2h15 rôti de porc", [{ ms: 2 * H + 15 * MIN, label: "rôti de porc" }]);
check("timer 1h 30min", [{ ms: 90 * MIN, label: "" }]);
check("timer 45 min four à pain", [{ ms: 45 * MIN, label: "four à pain" }]);
check("timer 10 min thé vert", [{ ms: 10 * MIN, label: "thé vert" }]);
check("timer 3 min œufs", [{ ms: 3 * MIN, label: "œufs" }]);
check("timer 8 min - riz", [{ ms: 8 * MIN, label: "riz" }]);
check("timer 5 min sel et poivre", [{ ms: 5 * MIN, label: "sel et poivre" }]);

// Heure cible
check("timer à 18:00", [{ at: "18:00", label: "" }]);
check("timer à 18h", [{ at: "18:00", label: "" }]);
check("timer a 18h30", [{ at: "18:30", label: "" }]);
check("alarme à 7h réveil", [{ at: "7:00", label: "réveil" }]);
check("timer at 6pm", [{ at: "18:00", label: "" }]);
check("timer at 6:30 pm", [{ at: "18:30", label: "" }]);
check("timer vers midi", [{ at: "12:00", label: "" }]);
check("rappel à 22h appeler maman", [{ at: "22:00", label: "appeler maman" }]);
check("timer 14h30", [{ at: "14:30", label: "" }, { ms: 14 * H + 30 * MIN, label: "" }]);
check("timer 18:00", [{ ms: 18 * MIN, label: "" }, { at: "18:00", label: "" }]);


// Exemples cités dans le README
check("25m focus", [{ ms: 25 * MIN, label: "focus" }]);
check("4m tea", [{ ms: 4 * MIN, label: "tea" }]);
check("at 18:30 train", [{ at: "18:30", label: "train" }]);
check("timer 7am wake up", [{ at: "7:00", label: "wake up" }]);
check("at noon", [{ at: "12:00", label: "" }]);
check("pasta for 12 min", [{ ms: 12 * MIN, label: "pasta" }]);
check("timer 1 hour and a half", [{ ms: 90 * MIN, label: "" }]);
check("1h laundry", [{ ms: H, label: "laundry" }]);
check("timer 50 min meeting", [{ ms: 50 * MIN, label: "meeting" }]);
check("90 min", [{ ms: 90 * MIN, label: "" }]);

// Ce qui n'est pas un minuteur
check("firefox", []);
check("timer", []);
check("minuteur pâtes", []);
check("spotify", []);
check("mes 2 chats", []);
check("= 2+2", []);
check("timer 0 min", []);

// Mise en forme
function eq(a, b) {
    count++;
    if (a !== b) {
        failures++;
        print("✗ format : attendu " + JSON.stringify(b) + ", obtenu " + JSON.stringify(a));
    }
}
eq(TP.formatClock(20 * MIN), "20:00");
eq(TP.formatClock(20 * MIN - 1), "20:00");
eq(TP.formatClock(9 * MIN + 5 * S), "9:05");
eq(TP.formatClock(H + 2 * MIN + 3 * S), "1:02:03");
eq(TP.formatClock(0), "0:00");
eq(TP.formatClock(-12 * S - 300), "−0:12");
eq(TP.formatClock(-300), "0:00");
eq(TP.formatHuman(90 * MIN), "1 h 30");
eq(TP.formatHuman(2 * H), "2 h");
eq(TP.formatHuman(20 * MIN), "20 min");
eq(TP.formatHuman(90 * S), "1 min 30 s");
eq(TP.formatHuman(45 * S), "45 s");
eq(TP.formatRelative(2 * H + 16 * MIN), "2 h 16");
eq(TP.formatTimeOfDay(new Date(2026, 8, 24, 22, 4).getTime(), true), "22:04");
eq(TP.formatTimeOfDay(new Date(2026, 8, 24, 22, 4).getTime(), false), "10:04 PM");

print(failures === 0 ? "✓ " + count + " tests réussis" : "\n" + failures + " / " + count + " échecs");
imports.system.exit(failures === 0 ? 0 : 1);
