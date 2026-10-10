.pragma library

// Pure history rules for the time journal and the favourites: which finished
// timers are kept, how their time is split per day and per week, which names
// are started most. No QML, no side effects; the file on disk is another
// module's job. A history is { records: [{ name, start, end }] } with epoch
// milliseconds, oldest first. Every function returns a new value.

// Caps, so a hostile or corrupted file can never grow the shell's memory
const MAX_NAME = 60;
const MAX_RECORDS = 5000;
const MAX_TEXT = 1048576;
const MAX_SPAN = 366 * 86400000;
const KEEP_MONTHS = 12;
const FAVOURITES = 3;

function empty() {
    return { records: [] };
}

function cleanName(name) {
    return typeof name === "string" ? name.trim().slice(0, MAX_NAME) : "";
}

// A valid record, or null: a name, finite times, a positive span of at most a year
function cleanRecord(r) {
    if (!r || typeof r !== "object")
        return null;
    const name = cleanName(r.name);
    if (name === "" || !Number.isFinite(r.start) || !Number.isFinite(r.end))
        return null;
    if (r.end <= r.start || r.end - r.start > MAX_SPAN)
        return null;
    return { name: name, start: Math.floor(r.start), end: Math.floor(r.end) };
}

// Drops what ended more than 12 months before `now`, then keeps the newest records
function prune(records, now) {
    const limit = new Date(now);
    limit.setMonth(limit.getMonth() - KEEP_MONTHS);
    const kept = records.filter(r => r.end >= limit.getTime());
    return kept.length > MAX_RECORDS ? kept.slice(kept.length - MAX_RECORDS) : kept;
}

// The history saved in `text`. Empty, corrupted or foreign text gives an
// empty history, never an exception; bad records are skipped one by one.
function parse(text, now) {
    if (typeof text !== "string" || text === "" || text.length > MAX_TEXT)
        return empty();
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return empty();
    }
    if (!data || !Array.isArray(data.records))
        return empty();
    const records = [];
    for (const r of data.records.slice(0, MAX_RECORDS * 2)) {
        const c = cleanRecord(r);
        if (c)
            records.push(c);
    }
    return { records: prune(records, now) };
}

function serialize(history) {
    return JSON.stringify({ records: history.records });
}

// `history` plus a finished timer (ignored if invalid), pruned at `now`
function add(history, name, start, end, now) {
    const c = cleanRecord({ name: name, start: start, end: end });
    const records = c ? history.records.concat([c]) : history.records;
    return { records: prune(records, now) };
}

function pad(n) {
    return n < 10 ? "0" + n : String(n);
}

// "YYYY-MM-DD" of a local date
function dayKey(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

// The Monday of the local week holding `d`, as a day key
function weekKey(d) {
    const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7);
    return dayKey(monday);
}

// [{ name, day, week, ms }] one entry per record and local day it touches:
// a timer crossing midnight is split between its days, at local midnight
function slices(history) {
    const out = [];
    for (const r of history.records) {
        let from = r.start;
        while (from < r.end) {
            const d = new Date(from);
            const midnight = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime();
            const to = Math.min(r.end, midnight);
            out.push({ name: r.name, day: dayKey(d), week: weekKey(d), ms: to - from });
            from = to;
        }
    }
    return out;
}

// Adds up slices by name and by the key `by` ("day" or "week"), in order of
// first appearance: [{ name, <by>, ms }]
function total(history, by) {
    const sums = new Map();
    for (const s of slices(history)) {
        const k = s.name + "\n" + s[by];
        if (!sums.has(k)) {
            const e = { name: s.name };
            e[by] = s[by];
            e.ms = 0;
            sums.set(k, e);
        }
        sums.get(k).ms += s.ms;
    }
    return [...sums.values()];
}

function perDay(history) {
    return total(history, "day");
}

function perWeek(history) {
    return total(history, "week");
}

// The `count` (3 by default) most started names, as [{ name, count }]. On a
// tie the name that was started first comes first, so the order is stable.
function favourites(history, count) {
    const counts = new Map();
    for (const r of history.records)
        counts.set(r.name, (counts.get(r.name) || 0) + 1);
    return [...counts.entries()].map(e => ({ name: e[0], count: e[1] })).sort((a, b) => b.count - a.count).slice(0, count === undefined ? FAVOURITES : count);
}
