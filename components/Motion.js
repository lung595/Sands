.pragma library

// Looping motion as pure functions of time.
//
// Why: a QML animation that loops (Animator, NumberAnimation, FrameAnimation)
// keeps the shared animation clock ticking, so EVERY DMS window (bars,
// wallpaper) redraws at the display rate (240 Hz here) for as long as it runs.
// Measured: open panel 87 % of a core, paused panel 106 %. Instead, one plain
// Timer advances a clock (only the window that shows it redraws) and each
// moving value is computed from that clock with the functions below. They
// reproduce the former animations: same ranges, periods and easing.

// Smooth back-and-forth between lo and hi, starting at lo, with the given
// period. Same shape as an InOutSine loop lo → hi → lo.
function wave(t, period, lo, hi) {
    const k = (1 - Math.cos(2 * Math.PI * t / period)) / 2;
    return lo + (hi - lo) * k;
}

// Alarm bell shake, one cycle per 1070 ms: 0 → 14° → −14° → 10° → 0°
// (linear, 70 / 140 / 120 / 90 ms), then still for 650 ms.
const BELL = [[0, 0], [70, 14], [210, -14], [330, 10], [420, 0], [1070, 0]];
function bellAngle(ms) {
    const t = ms % 1070;
    for (let i = 1; i < BELL.length; i++) {
        const a = BELL[i - 1], b = BELL[i];
        if (t <= b[0])
            return a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0]);
    }
    return 0;
}

// Last ten seconds: one beat per second. Up to 1.22 in 110 ms (OutQuad),
// back to 1 in 390 ms (OutCubic), then still.
function beatScale(ms) {
    const t = ms % 1000;
    if (t < 110) {
        const k = t / 110;
        return 1 + 0.22 * (1 - (1 - k) * (1 - k));
    }
    if (t < 500) {
        const k = (t - 110) / 390;
        return 1.22 - 0.22 * (1 - Math.pow(1 - k, 3));
    }
    return 1;
}

// Frost crystal sparkle. Each crystal has its own random numbers h1..h3
// (0..1): a rest of h1 × 3 s, a rise to 0.95, a fall to 0.25, looping.
function sparkle(ms, h1, h2, h3) {
    const rest = h1 * 3000, up = 900 + h2 * 800, down = 1400 + h3 * 900;
    const t = ms % (rest + up + down);
    if (t < rest)
        return 0.25;
    if (t < rest + up)
        return 0.25 + 0.7 * (1 - Math.cos(Math.PI * (t - rest) / up)) / 2;
    return 0.95 - 0.7 * (1 - Math.cos(Math.PI * (t - rest - up) / down)) / 2;
}

// Frost crystal drift: 2 px → −4 px → 2 px, over two uneven halves.
function drift(ms, h2, h3) {
    const a = 5000 + h2 * 3000, b = 5000 + h3 * 3000;
    const t = ms % (a + b);
    if (t < a)
        return 2 - 6 * (1 - Math.cos(Math.PI * t / a)) / 2;
    return -4 + 6 * (1 - Math.cos(Math.PI * (t - a) / b)) / 2;
}
