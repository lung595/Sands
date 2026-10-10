// Plans.js tests — run with: gjs tests/plans.test.js (from the plugin root)
// Focus cycles and chained timers, in English and French; anything that is
// not clearly a plan must give null so the single-timer parser stays in charge.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const P = load("Plans.js");
const MIN = 60000, H = 3600000;

const cycle = (repeats, focus, pause) => ({ kind: "cycle", repeats, phases: [{ label: "Focus", ms: focus }, { label: "Break", ms: pause }] });
const chain = (...steps) => ({ kind: "chain", repeats: 1, phases: steps.map(([label, ms]) => ({ label, ms })) });

// Cycles
eq(P.parse("4x 25/5"), cycle(4, 25 * MIN, 5 * MIN), "4x 25/5");
eq(P.parse("4 x 25 / 5"), cycle(4, 25 * MIN, 5 * MIN), "spaces");
eq(P.parse("4×25/5"), cycle(4, 25 * MIN, 5 * MIN), "times sign");
eq(P.parse("25/5 x4"), cycle(4, 25 * MIN, 5 * MIN), "count after");
eq(P.parse("pomodoro 4 cycles 25/5"), cycle(4, 25 * MIN, 5 * MIN), "pomodoro cycles");
eq(P.parse("3 cycles of 50m/10m"), cycle(3, 50 * MIN, 10 * MIN), "cycles of, units");
eq(P.parse("4 fois 25/5"), cycle(4, 25 * MIN, 5 * MIN), "fr fois");
eq(P.parse("25/5 4 fois"), cycle(4, 25 * MIN, 5 * MIN), "fr count after");
eq(P.parse("2x 1h/10 min"), cycle(2, H, 10 * MIN), "hour and minute units");
eq(P.parse("2x 1h30/15min"), cycle(2, 90 * MIN, 15 * MIN), "1h30");
eq(P.parse("3x 90s/30s"), cycle(3, 90000, 30000), "seconds");
eq(P.parse("20x 1/1").repeats, 20, "20 repeats allowed");

// Chains
eq(P.parse("pasta 10 then sauce 5"), chain(["pasta", 10 * MIN], ["sauce", 5 * MIN]), "en chain");
eq(P.parse("10 min pâtes puis 5 min sauce"), chain(["pâtes", 10 * MIN], ["sauce", 5 * MIN]), "fr chain, accents kept");
eq(P.parse("tea 3 min, toast 2 min, eggs 6 min"), chain(["tea", 3 * MIN], ["toast", 2 * MIN], ["eggs", 6 * MIN]), "commas");
eq(P.parse("a 1h30 > b 45s"), chain(["a", 90 * MIN], ["b", 45000]), "arrow, mixed units");
eq(P.parse("10 and then 5"), chain(["", 10 * MIN], ["", 5 * MIN]), "no names");
eq(P.parse("timer pour 10 min ensuite thé 5"), chain(["", 10 * MIN], ["thé", 5 * MIN]), "filler words dropped");
eq(P.parse("rice 1,5 then beans 2")?.phases[0].ms, 90000, "decimal comma is not a separator");

// Not a plan: today's parser keeps these
for (const text of ["", "   ", "timer 10", "pasta 10", "10 min pasta", "5", "4x 25", "25/5", "hello", "buy milk then call mom",
    "pasta 10 then sauce", "pasta 10 then", "then 10 then 5", "a 5 6 then b 2", "0x 25/5", "4x 25/0", "1,5/", "dans 5 min", "4x 25/5/10"])
    eq(P.parse(text), null, "null: " + JSON.stringify(text));

// Caps
eq(P.parse("21x 25/5"), null, "too many repeats");
eq(P.parse("4x 101h/5"), null, "phase over 100 h");
eq(P.parse("4x 0.01/5"), null, "phase under 1 s");
eq(P.parse(Array(11).fill("a 1").join(" then ")), null, "too many chain steps");
eq(P.parse(Array(10).fill("a 1").join(" then ")).phases.length, 10, "10 chain steps allowed");
eq(P.parse("x".repeat(P.MAX_INPUT + 1) + " 10 then 5"), null, "input too long");
eq(P.parse("a".repeat(100) + " 10 then b 5").phases[0].label.length, P.MAX_LABEL, "label capped");
eq(P.parse(null), null, "not a string");
eq(P.parse(42), null, "number");
eq(P.parse("pasta\u0001 10 then x 5").phases[0].label, "pasta", "control characters removed");

done();
