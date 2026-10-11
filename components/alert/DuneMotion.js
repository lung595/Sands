.pragma library
.import "DuneStyles.js" as Styles

// Motion model of the "Rising dune" alert. Pure: the state at step n depends
// only on (style, n, seed), so a test replays the same frames and the view
// just draws what it is given. Coordinates are unit-less: x across the band
// 0..1, heights and grain y as a share of the band height. Nothing here runs
// by itself; a 30 Hz Timer in the view asks for one state per tick and stops
// when `done` is true.
var STEP_HZ = 30;
var COLUMNS = 24;

// Hard stop of each style in seconds (design.md §10, rising-dune.html).
var DURATION = { grains: 2.9, wind: 2.6, wave: 2.4 };

// Where the crest sits across the band, and how low the dune's feet lie.
var CREST = { grains: 0.5, wind: 0.75, wave: 0.62 };
var FOOT = { grains: 0.55, wind: 0.3, wave: 0.35 };
var GRAINS = { grains: 70, wind: 40 };
// Reach of the grain spread and of the wind front: past 1.21 / 1.23 so every
// column is fully covered before the hard stop and the last frame is the posed dune
var SPREAD = 1.25;
var FRONT = 1.3;

// "Flat wave" beats: share of height lost, start and length in seconds.
var BEATS = [[0.7, 0.42, 0.20], [1.12, 0.32, 0.11], [1.44, 0.24, 0.05]];
// Fine sand thrown off the crest at the overshoot and at each thud: time, count, power.
var PUFFS = [[0.47, 10, 1], [0.826, 12, 1], [1.216, 7, 0.74], [1.512, 4, 0.5]];
var GRAVITY = 2.4;

function clamp(v) {
    return v < 0 ? 0 : v > 1 ? 1 : v;
}

function smooth(v) {
    v = clamp(v);
    return v * v * (3 - 2 * v);
}

function outQuad(v) {
    return 1 - (1 - clamp(v)) * (1 - clamp(v));
}

// Ease-out with one overshoot of about 18 % (k = 2.425)
function back(v) {
    v = clamp(v) - 1;
    return 1 + 3.425 * v * v * v + 2.425 * v * v;
}

// Mulberry32: tiny seeded generator, closed over its own state
function rng(seed) {
    let a = seed | 0;
    return function () {
        a = a + 0x6D2B79F5 | 0;
        let t = Math.imul(a ^ a >>> 15, 1 | a);
        t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
}

function steps(style, reduceMotion) {
    return reduceMotion ? 0 : Math.round(DURATION[Styles.resolve(style)] * STEP_HZ);
}

// Resting shape: long slope up to the crest, shorter face down
function pose(style, x) {
    const c = CREST[style], f = FOOT[style];
    return x < c ? f + (1 - f) * smooth(x / c) : 1 - (1 - f) * smooth((x - c) / (1 - c)) * 0.8;
}

// Share of height lost during the "Flat wave" beats: a thud, then it builds back
function beat(t) {
    for (let i = 0; i < BEATS.length; i++) {
        const v = (t - BEATS[i][0]) / BEATS[i][1];
        if (v > 0 && v < 1)
            return BEATS[i][2] * (v < 0.3 ? 1 - Math.pow(1 - v / 0.3, 3) : 1 - smooth((v - 0.3) / 0.7));
    }
    return 0;
}

// Body height of the wave at time t (1 = posed)
function waveBody(t) {
    if (t < 0.2)
        return 0.08 * smooth(t / 0.2);
    if (t < 0.7)
        return 0.08 + 0.92 * back((t - 0.2) / 0.5);
    return 1 - beat(t);
}

function lean(t) {
    return t < 0.2 ? 0 : 0.16 * smooth((t - 0.2) / 0.25) * (1 - smooth((t - 0.7) / 1.3));
}

// Column heights at time t; the cover of each column is what differs per style
function heights(style, t) {
    const out = [], c = CREST[style];
    for (let i = 0; i < COLUMNS; i++) {
        const x = (i + 0.5) / COLUMNS, p = pose(style, x);
        let h;
        if (style === "grains") {
            h = p * clamp((outQuad(t / 2.0) * SPREAD - Math.abs(2 * x - 1)) * 4) * outQuad(t / 2.2);
        } else if (style === "wind") {
            const front = outQuad(t / 1.5) * FRONT;
            h = p * clamp((front - x) * 4) + (t < 1.7 ? 0.06 * Math.exp(-Math.pow((x - front) / 0.08, 2)) : 0);
        } else {
            // Crest leads on the rise (flanks 120 ms later), then trails the body by 40 ms
            const d = Math.abs(x - c) / Math.max(c, 1 - c);
            h = p * waveBody(t - (t < 0.7 ? 0.12 * d : 0.04 * (1 - d)));
        }
        out.push(Math.max(0, h));
    }
    return out;
}

// Every grain of a run (wind grains may leave the band: the view clips), launched at a seeded time with a seeded velocity.
// Wave puffs leave the crest; the other styles sprinkle the front.
function plan(style, seed) {
    const r = rng(seed), list = [];
    const c = CREST[style];
    if (style === "wave") {
        for (const puff of PUFFS)
            for (let k = 0; k < puff[1]; k++)
                list.push({ t0: puff[0], x0: c + (r() - 0.5) * 0.04, vx: (r() - 0.5) * 0.5 * puff[2], vy: (0.7 + r() * 0.9) * puff[2], life: 0.5 });
    } else {
        for (let k = 0; k < GRAINS[style]; k++) {
            const t0 = r() * (style === "grains" ? 1.6 : 1.5);
            list.push(style === "grains"
                ? { t0, x0: 0.5 + (r() - 0.5) * 0.02, vx: (r() - 0.5) * 0.7, vy: 0.3 + r() * 0.5, life: 0.3 + r() * 0.4 }
                : { t0, x0: outQuad(t0 / 1.5) * FRONT - r() * 0.2, vx: 0.15 + r() * 0.3, vy: 0.2 + r() * 0.6, life: 0.3 + r() * 0.4 });
        }
    }
    return list;
}

function grainsAt(list, t) {
    const out = [];
    for (const g of list) {
        const u = t - g.t0;
        if (u < 0 || u > g.life)
            continue;
        out.push({ x: g.x0 + g.vx * u, y: Math.max(0, g.vy * u - GRAVITY * u * u / 2) });
    }
    return out;
}

// The posed dune: what the view draws at rest, after the last step, and
// for Reduce motion
function posed(style) {
    const out = [];
    for (let i = 0; i < COLUMNS; i++)
        out.push(pose(style, (i + 0.5) / COLUMNS));
    return { style, step: 0, steps: 0, done: true, heights: out, crest: CREST[style], lean: 0, squash: 0, grains: [] };
}

// State at step n of a run. `done` flips on the last step; later steps return
// the same posed state. `reduceMotion` returns the posed dune with 0 step.
function stateAt(style, n, seed, reduceMotion) {
    style = Styles.resolve(style);
    const total = steps(style, reduceMotion);
    if (!(n < total)) {
        const s = posed(style);
        s.step = total;
        s.steps = total;
        return s;
    }
    const t = n / STEP_HZ, wave = style === "wave";
    return {
        style, step: n, steps: total, done: false,
        heights: heights(style, t),
        crest: CREST[style],
        lean: wave ? lean(t) : 0,
        squash: wave ? beat(t) : 0,
        grains: grainsAt(plan(style, seed), t)
    };
}

// D482: nothing is drawn over a full-screen app unless the user asked for it
function shouldDraw(fullscreen, showOverFullscreen) {
    return !fullscreen || showOverFullscreen === true;
}
