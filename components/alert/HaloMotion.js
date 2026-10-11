.pragma library

// Pure steps of the Edge halo: rise, 3 beats, then rest. A finite list that
// a Timer at 30 Hz walks through and then stops: nothing moves after the
// last step, which is the posed rim. No QML, no side effects.

const RISE_MS = 200;
const BEAT_MS = 600;
const BEATS = 3;
const EXIT_MS = 150;
const HZ = 30;
const FRAME_MS = 1000 / HZ;
// The page's easing, cubic-bezier(0.2, 0, 0, 1), solved by bisection on x
function ease(p) {
    if (p <= 0)
        return 0;
    if (p >= 1)
        return 1;
    const bez = (a, b, u) => 3 * a * u * (1 - u) * (1 - u) + 3 * b * u * u * (1 - u) + u * u * u;
    let lo = 0, hi = 1;
    for (let i = 0; i < 24; i++) {
        const mid = (lo + hi) / 2;
        if (bez(0.2, 0, mid) < p)
            lo = mid;
        else
            hi = mid;
    }
    return bez(0, 1, (lo + hi) / 2);
}

// Opacity of the posed rim (also the top of a beat) and of a beat's dip, as
// on the approved page: each beat dips to half and comes back
const REST = 1;
const TROUGH = 0.5;

function round(v) {
    return Math.round(v * 1000) / 1000;
}

// Opacity of a beat at phase 0..1: rest, down to the dip at mid-beat, back;
// each half-beat follows the page's easing
function beatAt(phase) {
    const half = phase < 0.5 ? ease(phase * 2) : 1 - ease(phase * 2 - 1);
    return REST - (REST - TROUGH) * half;
}

// The whole sequence as [{ t (ms), opacity }]. Reduce motion gives no step:
// the caller shows the posed rim at once.
function steps(reduceMotion) {
    if (reduceMotion === true)
        return [];
    const total = RISE_MS + BEATS * BEAT_MS;
    const list = [];
    const frames = Math.round(total / FRAME_MS);
    for (let i = 0; i < frames; i++) {
        const t = i * FRAME_MS;
        const o = t < RISE_MS ? REST * ease(t / RISE_MS) : beatAt(((t - RISE_MS) % BEAT_MS) / BEAT_MS);
        list.push({ t: Math.round(t), opacity: round(o) });
    }
    list.push({ t: total, opacity: REST });
    return list;
}

// The opacity once the sequence is over (and the only state in Reduce motion)
function posed() {
    return REST;
}

// Fade out from `from` to 0 in 150 ms
function exitSteps(fromOpacity) {
    const from = Math.min(1, Math.max(0, Number(fromOpacity) || 0));
    const list = [];
    const frames = Math.round(EXIT_MS / FRAME_MS);
    for (let i = 1; i < frames; i++) {
        const t = i * FRAME_MS;
        list.push({ t: Math.round(t), opacity: round(from * (1 - ease(t / EXIT_MS))) });
    }
    list.push({ t: EXIT_MS, opacity: 0 });
    return list;
}
