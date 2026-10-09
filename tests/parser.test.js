// TimeParser.js tests — run with: gjs -m tests/parser.test.js
// (or: gjs tests/parser.test.js from the plugin root)
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/parser.test.js", GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/TimeParser.js");
const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
const TP = new Function(src + "; return { parse, tooLong, MAX_INPUT, MAX_LABEL, formatClock, formatHuman, formatRelative, formatTimeOfDay };")();

// Wednesday, Sept 24 2026, 21:47:00 local time
const NOW = new Date(2026, 8, 24, 21, 47, 0, 0).getTime();
const MIN = 60000, H = 3600000, S = 1000;

let failures = 0, count = 0, countChecks = 0;

function check(input, expected, opts) {
    count++;
    const res = TP.parse(input, NOW, opts);
    const got = res.map(r => r.kind === "at"
        ? { at: new Date(r.at).getHours() + ":" + String(new Date(r.at).getMinutes()).padStart(2, "0"), label: r.label }
        : { ms: r.ms, label: r.label });
    const ok = JSON.stringify(got) === JSON.stringify(expected);
    if (!ok) {
        failures++;
        print("✗ " + JSON.stringify(input) + "\n    expected: " + JSON.stringify(expected) + "\n    got:      " + JSON.stringify(got));
    }
}

// Simple durations
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

// Spelled out
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

// Labels
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

// Target time
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


// Examples quoted in the README
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

// Natural durations (NAK-150)
check("dans 20 minutes", [{ ms: 20 * MIN, label: "" }]);
check("in 20 minutes", [{ ms: 20 * MIN, label: "" }]);
check("vingt minutes", [{ ms: 20 * MIN, label: "" }]);
check("un quart d'heure", [{ ms: 15 * MIN, label: "" }]);
check("trois quarts d'heure", [{ ms: 45 * MIN, label: "" }]);
check("20 minutes et demie", [{ ms: 20.5 * MIN, label: "" }]);
check("quarter of an hour", [{ ms: 15 * MIN, label: "" }]);
check("three quarters of an hour", [{ ms: 45 * MIN, label: "" }]);
check("an hour and a half", [{ ms: 90 * MIN, label: "" }]);

// Context verbs are dropped, the rest is the label
check("rappelle-moi de sortir le linge dans 20 minutes", [{ ms: 20 * MIN, label: "sortir le linge" }]);
check("rappelle-moi dans vingt minutes de sortir le linge", [{ ms: 20 * MIN, label: "sortir le linge" }]);
check("rappelle moi d'appeler maman dans 10 min", [{ ms: 10 * MIN, label: "appeler maman" }]);
check("remind me to take out the laundry in 20 minutes", [{ ms: 20 * MIN, label: "take out the laundry" }]);
check("remind me in 20 minutes to take out the laundry", [{ ms: 20 * MIN, label: "take out the laundry" }]);
check("set a timer for 20 minutes", [{ ms: 20 * MIN, label: "" }]);
check("set a timer for 20 minutes for the pasta", [{ ms: 20 * MIN, label: "pasta" }]);
check("mets un minuteur de 20 minutes pour les pâtes", [{ ms: 20 * MIN, label: "pâtes" }]);
check("remind me to call mum 10", [{ ms: 10 * MIN, label: "call mum" }]);

// A bare number closing a text is minutes, within limits
check("pasta 12", [{ ms: 12 * MIN, label: "pasta" }]);
check("Pasta 12", [{ ms: 12 * MIN, label: "Pasta" }]);
check("pâtes 12", [{ ms: 12 * MIN, label: "pâtes" }]);
check("pasta 180", [{ ms: 180 * MIN, label: "pasta" }]);
check("12", []);
check("pasta 181", []);
check("pasta 200", []);
check("pasta 0", []);
check("dans 12", []);
check("= 2+2", []);
check("mes 2 chats", []);

// Unit typos: one letter off, units only
check("20 mni", [{ ms: 20 * MIN, label: "" }]);
check("1 heur", [{ ms: H, label: "" }]);
check("1 heur 30", [{ ms: 90 * MIN, label: "" }]);
check("20 minuts pasta", [{ ms: 20 * MIN, label: "pasta" }]);
check("vingt minuts", [{ ms: 20 * MIN, label: "" }]);
check("10 secnds tea", [{ ms: 10 * S, label: "tea" }]);
check("5 hurs", [{ ms: 5 * H, label: "" }]);
// Ordinary words next to a number stay words
check("5 four", []);
check("5 pour pasta", []);
check("2 men", []);
// Real French words one letter off a unit are not hours
check("3 jours", []);
check("dans 3 jours", []);
check("4 cours", []);
check("3 tours de piste", []);
check("2 hors", []);
check("timer 3 jours", [{ ms: 3 * MIN, label: "jours" }]);
// Labels are never corrected
check("20 min pasat", [{ ms: 20 * MIN, label: "pasat" }]);

// What is not a timer
check("firefox", []);
check("timer", []);
check("minuteur pâtes", []);
check("spotify", []);
check("mes 2 chats", []);
check("= 2+2", []);
check("timer 0 min", []);

// Repeat: « 4x 1h » is four timers of one hour (count is checked apart)
check("4x 1h", [{ ms: H, label: "" }]);
check("4* 1h", [{ ms: H, label: "" }]);
check("4×1h", [{ ms: H, label: "" }]);
check("timer 3x 20 min pasta", [{ ms: 20 * MIN, label: "pasta" }]);
check("1h x4", [{ ms: H, label: "" }]);
check("2x 25m focus", [{ ms: 25 * MIN, label: "focus" }]);
check("4x", []);
check("2x pasta", []);

function checkCount(input, expected) {
    countChecks++;
    const got = TP.parse(input, NOW)[0]?.count;
    if (got !== expected) {
        failures++;
        print("✗ count " + JSON.stringify(input) + ": expected " + expected + ", got " + got);
    }
}
checkCount("4x 1h", 4);
checkCount("4* 1h", 4);
checkCount("timer 4x 1h", 4);
checkCount("1h x4", 4);
checkCount("1h", 1);
// Above the maximum: clamped and flagged so the launcher can say so,
// never ignored silently.
checkCount("99x 1h", 20);
countChecks++;
if (TP.parse("99x 1h", NOW)[0]?.capped !== true || TP.parse("4x 1h", NOW)[0]?.capped !== false) {
    failures++;
    print("✗ capped flag on \"99x 1h\"");
}

// Length caps (P118): a huge text is refused at once, a long label is cut
{
    const huge = "a ".repeat(40000);
    const t0 = Date.now();
    const r = TP.parse("12 min " + huge, NOW, { keyword: true });
    count++;
    if (r.length !== 0 || Date.now() - t0 > 50 || !TP.tooLong(huge) || TP.tooLong("12 min pasta")) {
        failures++;
        print("✗ a text over " + TP.MAX_INPUT + " characters is refused at once");
    }
    const long = TP.parse("12 min " + "pasta ".repeat(30), NOW)[0];
    count++;
    if (!long || long.label.length > TP.MAX_LABEL || long.ms !== 12 * MIN) {
        failures++;
        print("✗ a long label is cut to " + TP.MAX_LABEL + " characters");
    }
}

// Formatting
function eq(a, b) {
    count++;
    if (a !== b) {
        failures++;
        print("✗ format: expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
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

print(failures === 0 ? "✓ " + (count + countChecks) + " tests passed" : "\n" + failures + " / " + count + " failed");
imports.system.exit(failures === 0 ? 0 : 1);
