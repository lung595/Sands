// Hourglass geometry tests — run with: gjs tests/hourglass.test.js (from the plugin root)
// Checks the sand follows time by volume: monotonic, symmetric, conserved.
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/hourglass.test.js", GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/components/hourglass/Geometry.js");
const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
const G = new Function(src + "; return { dimensions, profile, volumes, level, sand, outline };")();
const [, frostBytes] = GLib.file_get_contents(dir + "/components/hourglass/FrostDraw.js");
const F = new Function(new TextDecoder().decode(frostBytes).replace(".pragma library", "") + "; return { star, rime };")();

// A 2D context that only records the calls the shapes make.
function recorder() {
    const calls = [];
    const rec = name => (...args) => calls.push({ name, args });
    return {
        calls,
        beginPath: rec("beginPath"), moveTo: rec("moveTo"), lineTo: rec("lineTo"),
        closePath: rec("closePath"), stroke: rec("stroke"), fill: rec("fill"), ellipse: rec("ellipse")
    };
}
const countOf = (ctx, name) => ctx.calls.filter(c => c.name === name).length;

let failures = 0, count = 0;

function check(ok, what) {
    count++;
    if (!ok) {
        failures++;
        print("✗ " + what);
    }
}

function near(got, expected, eps, what) {
    check(Math.abs(got - expected) <= eps, what + ": expected " + expected + ", got " + got);
}

const dim = G.dimensions(220, 250, false);
const got = G.dimensions(220, 250, true);
near(dim.hgH, 200, 1e-9, "classic height is 80% of the box");
near(dim.hgW, 120, 1e-9, "width is 60% of the height");
check(got.hgH < dim.hgH, "Glass of Time is smaller than the classic glass");
check(dim.neck >= 2.2 && dim.capH >= 6, "neck and cap have a minimum size");
near(dim.sphereR, dim.bulbL + dim.capH * 2.4, 1e-9, "sphere radius follows the bulb");
near(dim.gotSize, dim.sphereR * 2 + 8, 1e-9, "layer canvas holds the sphere plus its stroke");

// Profile: narrowest at the neck, widest at the rim end, clamped outside 0..1.
near(G.profile(dim, 0), dim.neck + (dim.bulbR - dim.neck) * 0.8 * 1, 1e-9, "profile at u=0 is the widest, at the rim end");
near(G.profile(dim, 1), dim.neck, 1e-9, "profile at u=1 closes back to the neck width");
near(G.profile(dim, -3), G.profile(dim, 0), 1e-12, "profile clamps below 0");
near(G.profile(dim, 9), G.profile(dim, 1), 1e-12, "profile clamps above 1");

const vol = G.volumes(dim);
check(vol.w.length === vol.N + 1, "one weight per step");
near(vol.total, vol.w.reduce((a, b) => a + b, 0), 1e-6, "total is the sum of the weights");

// Levels: u runs from the rim (0) to the neck (1). Sand held in the top
// bulb rises toward the rim as it grows; the extremes are exact.
near(G.level(vol, 0, true), 1, 1e-9, "no sand in the top: the level sits at the neck");
near(G.level(vol, 1, true), 0, 1e-9, "full top: the level sits at the rim");
near(G.level(vol, 0, false), 0, 1e-9, "no sand in the bottom: level 0");
near(G.level(vol, 1, false), 1, 1e-9, "full bottom: level 1");
let up = -1, down = 2, monotonic = true;
for (let p = 0; p <= 100; p++) {
    const top = G.level(vol, p / 100, true), bottom = G.level(vol, p / 100, false);
    if (top > down || bottom < up) monotonic = false;
    down = top;
    up = bottom;
}
check(monotonic, "top level only rises, bottom level only rises with the fraction");
// Fraction held below a level equals the fraction asked for (volume is conserved).
{
    const frac = 0.37, u = G.level(vol, frac, true);
    let held = 0;
    for (let k = 0; k <= vol.N; k++)
        if (k / vol.N >= u) held += vol.w[k];
    near(held / vol.total, frac, 0.01, "volume between the level and the neck matches the fraction");
}

// Sand state at the ends of a timer.
const full = G.sand(dim, vol, 1);
near(full.bottomU, 0, 1e-12, "full timer: nothing at the bottom");
check(full.topU < 1, "full timer: the top bulb is filled");
near(full.moundH, 0, 1e-12, "full timer: no mound");
const empty = G.sand(dim, vol, 0);
near(empty.topU, 1, 1e-12, "empty timer: nothing at the top");
const mid = G.sand(dim, vol, 0.5);
check(mid.moundH > 0 && mid.moundH <= dim.bulbL * 0.16, "mound grows but stays small");
check(mid.fallLength >= 4, "the stream is never shorter than 4 px");

// Frost shapes: a crystal has six arms, each reaching `size` from the center.
{
    const ctx = recorder();
    F.star(ctx, 10, 20, 5, 0);
    check(countOf(ctx, "stroke") === 6, "star draws six arms");
    const tips = ctx.calls.filter(c => c.name === "lineTo");
    check(tips.every(c => Math.abs(Math.hypot(c.args[0] - 10, c.args[1] - 20) - 5) < 1e-9), "every arm ends at `size` from the center");
    near(tips[0].args[0], 15, 1e-9, "phase 0 points the first arm to the right");
}
// Rime: one drop per count, sitting on the ledge, growing with the frost.
{
    const few = recorder(), many = recorder(), thin = recorder();
    F.rime(few, 1, 0, 100, 50, 4, 1);
    F.rime(many, 1, 0, 100, 50, 4, 2);
    F.rime(thin, 1, 0, 100, 50, 4, 0);
    check(countOf(few, "ellipse") === 4 && countOf(few, "fill") === 4, "rime draws one filled drop per count");
    const width = ctx => ctx.calls.filter(c => c.name === "ellipse").map(c => c.args[2]);
    check(width(many).every((w, i) => Math.abs(w - 2 * width(few)[i]) < 1e-9), "drop size scales with the frost");
    check(width(thin).every(w => w === 0), "no frost: the drops vanish");
    check(few.calls.filter(c => c.name === "ellipse").every(c => Math.abs(c.args[1] + c.args[3] / 2 - 50) < 1e-9), "drops sit on the ledge");
}
// Outline: a closed path hugging the profile on both sides of the neck.
{
    const ctx = recorder(), d = G.dimensions(220, 250, false);
    G.outline(ctx, d);
    check(countOf(ctx, "beginPath") === 1 && countOf(ctx, "closePath") === 1, "outline is one closed path");
    check(countOf(ctx, "lineTo") === 4 * 41, "outline walks four 41-point walls");
    const xs = ctx.calls.filter(c => c.name === "lineTo").map(c => c.args[0]);
    near(Math.max(...xs), -Math.min(...xs), 1e-9, "outline is symmetric around the neck axis");
    const widest = Math.max(...Array.from({ length: 41 }, (_, i) => G.profile(d, i / 40)));
    near(Math.max(...xs), widest, 1e-9, "outline reaches the widest point of the profile");
}

print(failures === 0 ? "✓ all " + count + " hourglass checks passed" : failures + " of " + count + " checks FAILED");
imports.system.exit(failures === 0 ? 0 : 1);
