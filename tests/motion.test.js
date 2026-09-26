// Motion.js tests — run with: gjs tests/motion.test.js (from the plugin root)
// Checks that each function matches the animation it replaces: same values
// at the key moments, continuous (no jump when a loop wraps), within range.
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/motion.test.js", GLib.get_current_dir())));
const [, bytes] = GLib.file_get_contents(dir + "/components/Motion.js");
const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
const M = new Function(src + "; return { wave, bellAngle, beatScale, sparkle, drift };")();

let failures = 0, count = 0;

function near(got, expected, what) {
    count++;
    if (Math.abs(got - expected) > 1e-6) {
        failures++;
        print("✗ " + what + ": expected " + expected + ", got " + got);
    }
}

// Largest step between two frames 1 ms apart over a whole cycle: a jump
// (a loop that does not wrap back to its start) would show up here.
function continuous(f, cycle, maxStep, what) {
    count++;
    let prev = f(0), worst = 0;
    for (let t = 1; t <= 2 * cycle; t++) {
        const v = f(t);
        worst = Math.max(worst, Math.abs(v - prev));
        prev = v;
    }
    if (worst > maxStep) {
        failures++;
        print("✗ " + what + " jumps by " + worst);
    }
}

function within(f, cycle, lo, hi, what) {
    count++;
    for (let t = 0; t <= cycle; t += 7) {
        const v = f(t);
        if (v < lo - 1e-9 || v > hi + 1e-9) {
            failures++;
            print("✗ " + what + " out of range at " + t + ": " + v);
            return;
        }
    }
}

// wave: starts at lo, reaches hi at half period, back to lo
near(M.wave(0, 4, 0.7, 1), 0.7, "wave start");
near(M.wave(2, 4, 0.7, 1), 1, "wave middle");
near(M.wave(4, 4, 0.7, 1), 0.7, "wave end");
within(t => M.wave(t / 1000, 1.3, 0.35, 1), 1300, 0.35, 1, "wave range");

// Bell: the former RotationAnimator keyframes
near(M.bellAngle(0), 0, "bell start");
near(M.bellAngle(70), 14, "bell right");
near(M.bellAngle(210), -14, "bell left");
near(M.bellAngle(330), 10, "bell right again");
near(M.bellAngle(420), 0, "bell back");
near(M.bellAngle(800), 0, "bell pause");
continuous(M.bellAngle, 1070, 0.21, "bell");

// Beat: 1 → 1.22 at 110 ms → 1 at 500 ms → still
near(M.beatScale(0), 1, "beat start");
near(M.beatScale(110), 1.22, "beat peak");
near(M.beatScale(500), 1, "beat back");
near(M.beatScale(900), 1, "beat pause");
continuous(M.beatScale, 1000, 0.005, "beat");

// Sparkle and drift, for a few crystals
for (const h of [[0, 0, 0], [0.3, 0.7, 0.1], [0.99, 0.5, 0.9]]) {
    const cycle = h[0] * 3000 + 900 + h[1] * 800 + 1400 + h[2] * 900;
    near(M.sparkle(0, h[0], h[1], h[2]), 0.25, "sparkle start");
    within(t => M.sparkle(t, h[0], h[1], h[2]), cycle, 0.25, 0.95, "sparkle range");
    continuous(t => M.sparkle(t, h[0], h[1], h[2]), cycle, 0.005, "sparkle");
    const dcycle = 10000 + (h[1] + h[2]) * 3000;
    near(M.drift(0, h[1], h[2]), 2, "drift start");
    within(t => M.drift(t, h[1], h[2]), dcycle, -4, 2, "drift range");
    continuous(t => M.drift(t, h[1], h[2]), dcycle, 0.005, "drift");
}

print(failures === 0 ? "✓ " + count + " tests passed" : "\n" + failures + " / " + count + " failed");
imports.system.exit(failures === 0 ? 0 : 1);
