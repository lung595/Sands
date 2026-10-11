// Pinned favourites: threshold, cap, texts, hostile names.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const P = load("components/favourites/Pins.js");
const H = load("components/daemon/History.js");
const MIN = 60000;

eq(P.pins(undefined), [], "no list");
eq(P.pins([]), [], "empty list");
eq(P.pins([{ name: "tea", count: 1, ms: 4 * MIN }]), [], "started once is not pinned");

const three = P.pins([
    { name: "work", count: 41, ms: 25 * MIN }, { name: "tea", count: 23, ms: 4 * MIN },
    { name: "pasta", count: 17, ms: 11 * MIN }, { name: "extra", count: 16, ms: MIN }]);
eq(three.length, 3, "never more than three");
eq(three[0].duration, "25 min", "duration text");
eq(three[0].startedText, "started 41 times", "count text");
eq(three[0].label, "Start 25 min work", "accessible name");
eq(three[1].ms, 4 * MIN, "duration kept for the restart");
eq(P.pins([{ name: "a", count: 2, ms: 500 }]), [], "damaged duration dropped");
eq(P.pins([null, { name: "", count: 5, ms: MIN }, { name: 5, count: 5, ms: MIN }, { name: "ok", count: "9", ms: MIN }]), [], "damaged entries dropped");
eq(P.pins([{ name: "Timer", count: 9, ms: MIN }, { name: "Alarm", count: 9, ms: MIN }]), [], "default names are never pinned (Q186)");
eq(P.pins([{ name: "a\u2014b\u2013c\u0007", count: 2, ms: MIN }])[0].name, "a - b - c", "dashes and controls removed");
eq(Array.from(P.pins([{ name: "x".repeat(100), count: 2, ms: MIN }])[0].name).length, 60, "name capped");
// Unnamed timers started most must not hide the named favourites (review round 2)
const recs = [];
[["Timer", 50], ["Alarm", 20], ["work", 10], ["tea", 9], ["pasta", 8]].forEach(e => {
    for (let i = 0; i < e[1]; i++)
        recs.push({ name: e[0], start: 0, end: MIN });
});
eq(P.pins(H.favourites({ records: recs }, H.FAVOURITES_MAX)).map(p => p.name), ["work", "tea", "pasta"], "named favourites survive unnamed ones");
done();
