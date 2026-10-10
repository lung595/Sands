// History.js tests — run with: gjs tests/history.test.js (from the plugin root)
// The time journal and the favourites: caps, corrupted text, midnight split.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const H = load("components/daemon/History.js");

const t = (y, mo, d, h, mi) => new Date(y, mo - 1, d, h || 0, mi || 0).getTime();
const NOW = t(2026, 10, 10, 12);
const MIN = 60000;

// Empty and unreadable text
eq(H.parse("", NOW), { records: [] }, "empty text");
eq(H.parse(undefined, NOW), { records: [] }, "no text");
eq(H.parse("{not json", NOW), { records: [] }, "corrupted text");
eq(H.parse("[1,2]", NOW), { records: [] }, "foreign JSON");
eq(H.parse("null", NOW), { records: [] }, "null JSON");
eq(H.parse("x".repeat(2000000), NOW), { records: [] }, "oversized text");
eq(H.favourites(H.empty()), [], "no favourites when empty");
eq(H.perDay(H.empty()), [], "no journal when empty");

// Bad records are skipped one by one
const mixed = JSON.stringify({ records: [
    { name: "tea", start: t(2026, 10, 9, 8), end: t(2026, 10, 9, 8, 5) },
    { name: "", start: 1, end: 2 }, { name: 5, start: 1, end: 2 }, null,
    { name: "x", start: "a", end: 2 }, { name: "x", start: 5, end: 5 },
    { name: "x", start: t(2020, 1, 1), end: t(2026, 1, 1) }
] });
eq(H.parse(mixed, NOW).records.map(r => r.name), ["tea"], "only the valid record survives");

// Round trip, name cap and trimming
let h = H.add(H.empty(), "  " + "n".repeat(100) + " ", t(2026, 10, 10, 9), t(2026, 10, 10, 9, 10), NOW);
eq(h.records[0].name.length, 60, "name capped at 60");
eq(H.parse(H.serialize(h), NOW), h, "serialize then parse");
eq(H.add(h, "", 1, 2, NOW), h, "empty name ignored");

// 12-month cap
let old = H.add(H.empty(), "old", t(2025, 10, 9), t(2025, 10, 9, 1), NOW);
eq(old.records.length, 0, "older than 12 months is dropped");
old = H.add(H.empty(), "edge", t(2025, 10, 11), t(2025, 10, 11, 1), NOW);
eq(old.records.length, 1, "just inside 12 months is kept");
const aged = H.parse(H.serialize(old), t(2026, 12, 1));
eq(aged.records.length, 0, "parse prunes at the given time");

// Record count cap keeps the newest
let many = H.empty();
for (let i = 0; i < 5100; i++)
    many = H.add(many, "n" + i, NOW - 2 * MIN, NOW - MIN, NOW);
eq(many.records.length, 5000, "at most 5000 records");
eq(many.records[4999].name, "n5099", "the newest are kept");

// Midnight split, per day and per week
const night = H.add(H.empty(), "study", t(2026, 10, 9, 23, 30), t(2026, 10, 10, 0, 45), NOW);
eq(H.perDay(night), [{ name: "study", day: "2026-10-09", ms: 30 * MIN }, { name: "study", day: "2026-10-10", ms: 45 * MIN }], "split between two days");
// 2026-10-10 is a Saturday: the week of 2026-10-05
eq(H.perWeek(night), [{ name: "study", week: "2026-10-05", ms: 75 * MIN }], "same week adds up");
const sunday = H.add(H.empty(), "run", t(2026, 10, 11, 23, 0), t(2026, 10, 12, 1, 0), t(2026, 10, 12, 2));
eq(H.perWeek(sunday), [{ name: "run", week: "2026-10-05", ms: 60 * MIN }, { name: "run", week: "2026-10-12", ms: 60 * MIN }], "Sunday midnight starts a new week");
let two = H.add(night, "study", t(2026, 10, 10, 10), t(2026, 10, 10, 10, 15), NOW);
eq(H.perDay(two)[1].ms, 60 * MIN, "two timers on one day add up");

// Favourites: most started, stable on ties, top 3
let f = H.empty();
for (const n of ["b", "a", "c", "a", "d", "b", "e", "a"])
    f = H.add(f, n, NOW - 10 * MIN, NOW - 5 * MIN, NOW);
eq(f.records.length, 8, "all added");
eq(H.favourites(f), [{ name: "a", count: 3 }, { name: "b", count: 2 }, { name: "c", count: 1 }], "top 3, ties by first start");
eq(H.favourites(f, 1).length, 1, "count argument");

// Review round 1: unknown clock, range, control characters, count, order
const base = H.add(H.empty(), "a", t(2026, 10, 9, 8), t(2026, 10, 9, 9), NOW);
eq(H.add(base, "b", t(2026, 10, 9, 10), t(2026, 10, 9, 11)).records.length, 2, "add without now keeps history");
eq(H.parse(H.serialize(base)).records.length, 1, "parse without now keeps history");
eq(H.parse(H.serialize(base), NaN).records.length, 1, "parse with NaN now keeps history");
eq(H.parse(JSON.stringify({ records: [{ name: "x", start: 9e15, end: 9e15 + 1000 }] }), NOW).records, [], "out of Date range");
eq(H.add(H.empty(), "x", t(2036, 1, 1), t(2036, 1, 1, 1), NOW).records, [], "future record rejected");
eq(H.add(H.empty(), "x", 0, 400 * 86400000, NOW).records, [], "span over the cap rejected");
eq(H.add(H.empty(), "a\nb\u0000\u001bc", t(2026, 10, 9), t(2026, 10, 9, 1), NOW).records[0].name, "abc", "control characters stripped");
eq(Array.from(H.add(H.empty(), "x".repeat(59) + "😀😀", t(2026, 10, 9), t(2026, 10, 9, 1), NOW).records[0].name).length, 60, "cut on code points");
let fav = H.empty();
for (const n of ["a", "b", "b"]) fav = H.add(fav, n, t(2026, 10, 9, 1 + fav.records.length), t(2026, 10, 9, 2 + fav.records.length), NOW);
eq(H.favourites(fav, -1), [], "negative count");
eq(H.favourites(fav, NaN), [], "NaN count");
eq(H.favourites(fav, 1e9).length, 2, "huge count clamped");
const unsorted = JSON.stringify({ records: [
    { name: "late", start: t(2026, 10, 9, 5), end: t(2026, 10, 9, 6) },
    { name: "early", start: t(2026, 10, 9, 1), end: t(2026, 10, 9, 2) }] });
eq(H.parse(unsorted, NOW).records.map(r => r.name), ["early", "late"], "parse sorts oldest first");
// Review round 2: a wrong clock must never wipe a valid file
eq(H.parse(H.serialize(base), t(2020, 1, 1)).records.length, 1, "clock gone backwards keeps records");
eq(H.parse(H.serialize(base), 1e16).records.length, 1, "now outside Date range keeps records");
eq(H.parse(H.serialize(base), NOW / 1000).records.length, 1, "now in seconds keeps records");
done();
