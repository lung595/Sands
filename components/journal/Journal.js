.pragma library

// Pure rules of the time journal screen: how a week of [{ name, ms }] (longest
// first, from the daemon read side) becomes rows, layer heights and thread
// lengths. No QML, no state, no side effect. Tested by tests/journal.test.js.

// Names shown before the rest folds into one line, per look
var STRATA_MAX = 5;
var THREADS_MAX = 7;
// Strata geometry in the glass's own units (viewBox 118 128 104 100)
var LAYERS_HEIGHT = 80;
var LAYER_MIN = 4;
// A thread is never shorter than its own track is tall, so it stays visible
var THREAD_MIN_PX = 8;

var MINUTE = 60000;

// "N min" under an hour, else "H h" or "H h MM"; at least "1 min" for any time
function duration(ms) {
    const minutes = Math.max(1, Math.round((Number.isFinite(ms) ? ms : 0) / MINUTE));
    if (minutes < 60)
        return minutes + " min";
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return h + " h" + (m ? " " + (m < 10 ? "0" + m : m) : "");
}

// A dash from outside (a timer name) never reaches the screen: plain hyphen
function plain(name) {
    return String(name).replace(/\s*[\u2013\u2014]\s*/g, " - ");
}

function sum(entries) {
    return entries.reduce((a, e) => a + e.ms, 0);
}

// At most `max` rows: the names past `max - 1` fold into one "N more names"
// row (times added up) when there are more than `max`. A row is
// { name, ms, folded } where `folded` is the number of names it stands for
// (0 for a real name).
function rows(entries, max) {
    const list = entries.map(e => ({ name: plain(e.name), ms: e.ms, folded: 0 }));
    if (list.length <= max)
        return list;
    const rest = list.slice(max - 1);
    return list.slice(0, max - 1).concat([{ name: rest.length + " more names", ms: sum(rest), folded: rest.length }]);
}

// Strata: the layer heights, bottom first (rows come longest first and the
// pile is built from the bottom), each at least LAYER_MIN
function layerHeights(shown) {
    const total = sum(shown);
    return shown.map(r => (total > 0 ? Math.max(LAYER_MIN, r.ms / total * LAYERS_HEIGHT) : LAYER_MIN));
}

// Threads: each thread's length as a fraction of the track, the longest being 1
function threadFractions(shown) {
    const longest = shown.reduce((a, r) => Math.max(a, r.ms), 0);
    return shown.map(r => (longest > 0 ? r.ms / longest : 0));
}

// Index of the texture of layer `i`: 0 solid, 1 light dots, 2 hatching,
// 3 stripes, 4 dots; the cycle starts again after the fifth
function textureOf(i) {
    return i % 5;
}
