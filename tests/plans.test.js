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
eq(P.parse("tea 1h30 > b 45s"), chain(["tea", 90 * MIN], ["b", 45000]), "arrow, mixed units");
eq(P.parse("10 and then 5"), chain(["", 10 * MIN], ["", 5 * MIN]), "no names");
eq(P.parse("timer pour 10 min ensuite thé 5"), chain(["", 10 * MIN], ["thé", 5 * MIN]), "filler words dropped");
eq(P.parse("rice 1,5 then beans 2")?.phases[0].ms, 90000, "decimal comma is not a separator");

// Not a plan: today's parser keeps these
for (const text of ["", "   ", "timer 10", "pasta 10", "10 min pasta", "5", "4x 25", "25/5", "hello", "buy milk then call mom",
    "pasta 10 then sauce", "5pm then 6pm", "call at 5pm then stretch 10 min", "at 17h then 10", "10kg rice then 5",
    "1.5.2 then 3", "x then 1e3", "1 h, 30 min", "eggs 2 min, 30 s", "10 min; 5 min", "5 pm then 6", "@ 10 then 5", "pasta 10 then", "then 10 then 5", "a 5 6 then b 2", "0x 25/5", "4x 25/0", "1,5/", "dans 5 min", "4x 25/5/10", "10:30 then 5", "1:30 then 2", "meet 9:15, call 10", "tea 10:30 then toast 5"])
    eq(P.parse(text), null, "null: " + JSON.stringify(text));

// Other accepted spellings
eq(P.parse("4 times 25/5"), cycle(4, 25 * MIN, 5 * MIN), "times before");
eq(P.parse("25/5 4 times"), cycle(4, 25 * MIN, 5 * MIN), "times after");
eq(P.parse("4 rounds 25/5"), cycle(4, 25 * MIN, 5 * MIN), "rounds");
eq(P.parse("4 sets 25/5"), cycle(4, 25 * MIN, 5 * MIN), "sets");
eq(P.parse("4*25/5"), cycle(4, 25 * MIN, 5 * MIN), "star");
eq(P.parse("focus 4x 25/5"), cycle(4, 25 * MIN, 5 * MIN), "focus prefix");
eq(P.parse("3 cycles d'25/5"), cycle(3, 25 * MIN, 5 * MIN), "d'");
eq(P.parse("4X 25/5"), cycle(4, 25 * MIN, 5 * MIN), "upper case cycle");
eq(P.parse("Pâtes 10 PUIS Sauce 5"), chain(["Pâtes", 10 * MIN], ["Sauce", 5 * MIN]), "upper case chain");
eq(P.parse("pasta 10, sauce 5"), chain(["pasta", 10 * MIN], ["sauce", 5 * MIN]), "bare minutes with comma");
eq(P.parse("tea 3 min, toast 2 min").phases.length, 2, "named comma steps");

// Caps
eq(P.parse("21x 25/5"), null, "too many repeats");
eq(P.parse("4x 101h/5"), null, "phase over 100 h");
eq(P.parse("4x 0.01/5"), null, "phase under 1 s");
eq(P.parse(Array(11).fill("tea 1").join(" then ")), null, "too many chain steps");
eq(P.parse(Array(10).fill("tea 1").join(" then ")).phases.length, 10, "10 chain steps allowed");
eq(P.parse("x".repeat(P.MAX_INPUT + 1) + " 10 then 5"), null, "input too long");
eq(P.parse("a".repeat(100) + " 10 then b 5").phases[0].label.length, P.MAX_LABEL, "label capped");
eq(P.parse(null), null, "not a string");
eq(P.parse(42), null, "number");
eq(P.parse("pasta\u0001 10 then x 5").phases[0].label, "pasta", "control characters removed");

done();
