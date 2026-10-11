// SandTint.js tests — run with: gjs tests/sand-tint.test.js
// Contrast floor under the caption, the four levels and the face rule.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const T = load("components/alert/SandTint.js");

const base = { r: 0.82, g: 0.74, b: 1 }, caption = { r: 0.22, g: 0.12, b: 0.45 }, text = { r: 0.9, g: 0.88, b: 0.96 };
const t = T.tints(base, caption, text);
eq(t.plain.length, 4, "four tints");
eq(t.capped.length, 4, "four capped tints");
eq(t.plain[2], base, "third tint is the base itself");
eq(t.capped.every(c => T.ratio(caption, c) >= T.FLOOR), true, "capped tints hold the floor");
eq(T.level(-0.9), 0, "deep shade");
eq(T.level(0), 2, "base");
eq(T.level(0.9), 3, "light");
eq(T.macro(1, 0, 0) > T.macro(-1, 0, 0), true, "climbing face is lighter than falling face");
eq(T.macro(1, 1, 0) < T.macro(1, 0, 0), true, "the skin light fades with depth");
eq(T.macro(0, 0, 1) < T.macro(0, 0, 0), true, "foot is darker");
const pal = T.palette(base, caption, text);
eq(T.tone(pal, 0, false), T.css(base), "tone 0 is the base");
eq(T.tone(pal, 0.3, false) !== T.tone(pal, 0.31, false), true, "tone is continuous");
eq(T.ratio(caption, { r: 0, g: 0, b: 0 }) >= 0, true, "ratio sane");
const dk = T.tone(pal, -1, true).match(/\d+/g).map(n => n / 255);
eq(T.ratio(caption, { r: dk[0], g: dk[1], b: dk[2] }) >= T.FLOOR - 0.05, true, "capped tone holds the floor");
done();
