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
// Opacity of the posed rim, and of a beat's peak
const REST = 0.35;
const PEAK = 1;

function round(v) {
    return Math.round(v * 1000) / 1000;
}

// Opacity of a beat at phase 0..1: rest, up to the peak, back to rest
function beatAt(phase) {
    return REST + (PEAK - REST) * (1 - Math.cos(2 * Math.PI * phase)) / 2;
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
        const o = t < RISE_MS ? REST * t / RISE_MS : beatAt(((t - RISE_MS) % BEAT_MS) / BEAT_MS);
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
function exitSteps(from) {
    const list = [];
    const frames = Math.round(EXIT_MS / FRAME_MS);
    for (let i = 1; i < frames; i++) {
        const t = i * FRAME_MS;
        list.push({ t: Math.round(t), opacity: round(from * (1 - t / EXIT_MS)) });
    }
    list.push({ t: EXIT_MS, opacity: 0 });
    return list;
}
