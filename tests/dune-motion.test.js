// DuneMotion.js tests — run with: gjs tests/dune-motion.test.js
// Each style ends by itself, the step count matches the duration, a seed
// replays the same frames, Reduce motion draws the posed dune, D482 rule.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const M = load("components/alert/DuneMotion.js");

const styles = ["grains", "wind", "wave"];
const dur = { grains: 2.9, wind: 2.6, wave: 2.4 };

for (const s of styles) {
    const n = M.steps(s, false);
    eq(n, Math.round(dur[s] * 30), s + " step count matches the duration at 30 Hz");
    eq(M.stateAt(s, n - 1, 1, false).done, false, s + " running on the last drawn step");
    const end = M.stateAt(s, n, 1, false);
    eq(end.done, true, s + " done at the last step");
    eq(JSON.stringify(M.stateAt(s, n + 50, 1, false).heights), JSON.stringify(end.heights), s + " no change after the end");
    eq(end.grains, [], s + " no grain after the end");
    eq(end.heights.length, M.COLUMNS, s + " column count");
    eq(end.heights.every(h => h > 0 && h <= 1), true, s + " posed heights in range");
    const a = [], b = [];
    for (let i = 0; i < n; i += 5) { a.push(M.stateAt(s, i, 42, false)); b.push(M.stateAt(s, i, 42, false)); }
    eq(JSON.stringify(a), JSON.stringify(b), s + " same seed, same frames");
    const mid = Math.floor(n / 3);
    eq(JSON.stringify(M.stateAt(s, mid, 1, false).grains) !== JSON.stringify(M.stateAt(s, mid, 2, false).grains), true, s + " another seed moves the grains");
    const r = M.stateAt(s, 10, 1, true);
    eq([r.done, r.steps, r.step, r.grains.length], [true, 0, 0, 0], s + " Reduce motion: posed, 0 step");
    eq(JSON.stringify(r.heights), JSON.stringify(end.heights), s + " Reduce motion shows the posed dune");
    eq(M.stateAt(s, 0, 1, false).heights.every(h => h < 0.3), true, s + " starts low");
}
eq(M.steps("bogus", false), 87, "unknown style uses grains");
eq(M.stateAt("bogus", 0, 1, false).style, "grains", "unknown style state");

// wave: overshoot above the posed height, then it settles to it
const w = n => Math.max(...M.stateAt("wave", n, 1, false).heights);
eq(w(14) > 1.0, true, "wave overshoots the posed crest near 0.47 s");
eq(M.stateAt("wave", 16, 1, false).grains.length > 0, true, "wave throws grains just after the overshoot");
// wind: the front crosses left to right
const wh = M.stateAt("wind", 20, 1, false).heights;
eq(wh[0] > wh[wh.length - 1], true, "wind front is further left than right at 0.67 s");

// D482
eq(M.shouldDraw(false, false), true, "windowed app: draw");
eq(M.shouldDraw(true, false), false, "full screen, setting off: no draw");
eq(M.shouldDraw(true, true), true, "full screen, setting on: draw");
eq(M.shouldDraw(true, undefined), false, "full screen, setting missing: no draw");
done();
