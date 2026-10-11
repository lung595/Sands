// HaloMotion.js tests — run with: gjs tests/halo-motion.test.js (from the plugin root)
// The Edge halo steps: rise, 3 beats at 30 Hz, rest; Reduce motion; exit.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const H = load("components/alert/HaloMotion.js");

const s = H.steps(false);
eq(s.length, 61, "step count: 2000 ms at 30 Hz plus the posed rim");
eq(s[0], { t: 0, opacity: 0 }, "starts invisible");
eq(s[s.length - 1], { t: 2000, opacity: H.posed() }, "ends on the posed rim");
eq(s.every((x, i) => i === 0 || x.t > s[i - 1].t), true, "time only moves forward");
eq(s.every(x => x.opacity >= 0 && x.opacity <= 1), true, "opacity stays in range");
eq(Math.max(...s.map(x => x.opacity)) > 0.95, true, "a beat reaches the peak");
// 3 beats: count the local maxima after the rise
const peaks = s.filter((x, i) => i > 0 && i < s.length - 1 && x.opacity > s[i - 1].opacity && x.opacity >= s[i + 1].opacity && x.opacity > 0.9);
eq(peaks.length, 3, "three beats");
eq(H.steps(true), [], "Reduce motion: no step");
eq(H.steps(undefined).length, 61, "motion on by default");

const e = H.exitSteps(0.8);
eq(e[e.length - 1], { t: 150, opacity: 0 }, "exit ends at 0 after 150 ms");
eq(e.every((x, i) => i === 0 || x.opacity < e[i - 1].opacity), true, "exit only fades");

done();
