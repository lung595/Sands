// Lifecycle.js tests — run with: gjs tests/lifecycle.test.js (from the plugin root)
// The state transitions of the timer list: order, pause/resume/adjust/restart,
// expiry, the next wake-up and the restore after a restart.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const L = load("components/daemon/Lifecycle.js");

const MAX = 100 * 3600 * 1000;
const run = (id, endAt) => ({ id: id, state: "running", endAt: endAt, total: 10000, remaining: 0, finishedAt: 0, kind: "duration" });

// Display order: ringing, then soonest, then paused
const order = L.sortTimers([
    { id: 1, state: "paused", remaining: 500 },
    run(2, 9000),
    run(3, 4000),
    { id: 4, state: "ringing", finishedAt: 100 }
]).map(t => t.id);
eq(order, [4, 3, 2, 1], "ringing, soonest running, later running, paused");
const input = [run(1, 5), run(2, 1)];
L.sortTimers(input);
eq(input.map(t => t.id), [1, 2], "sorting does not change the given list");

// A new timer
eq(L.make(7, 60000, "  tea  ", "duration", 0, 1000, 60), { id: 7, label: "tea", kind: "duration", total: 60000, endAt: 61000, remaining: 60000, state: "running", finishedAt: 0, hue: 0 }, "a duration timer");
eq(L.make(8, 0, "", "at", 90000, 1000, 60).endAt, 90000, "an alarm ends at its time");
eq(L.make(8, 0, "", "at", 90000, 1000, 60).total, 89000, "and lasts until then");
eq(L.make(9, 1000, "x".repeat(80), "weird", 0, 0, 60).label.length, 60, "the label is capped");
eq(L.make(9, 1000, "", "weird", 0, 0, 60).kind, "duration", "an unknown kind is a duration");

// Pause and resume
let t = run(1, 11000);
L.pause(t, 4000);
eq([t.state, t.remaining], ["paused", 7000], "pause keeps what was left");
L.resume(t, 20000);
eq([t.state, t.endAt], ["running", 27000], "resume ends after what was left");
t = { state: "ringing", endAt: 5 };
L.pause(t, 9);
eq(t.state, "ringing", "a ringing timer can't be paused");
t = run(1, 5000);
L.pause(t, 9000);
eq(t.remaining, 0, "pausing after the end keeps 0, not a negative time");

// Adjust
t = run(1, 11000);
eq(L.adjust(t, 1000, 60000, MAX), true, "+1 min on a running timer");
eq([t.endAt, t.total], [71000, 70000], "moves the end and grows the total");
t = { state: "paused", remaining: 5000, total: 8000, kind: "duration" };
eq(L.adjust(t, 0, -4000, MAX), true, "-4 s on a paused timer");
eq([t.remaining, t.total], [1000, 8000], "keeps the total");
t = { state: "paused", remaining: 5000, total: 8000, kind: "duration" };
eq(L.adjust(t, 0, -4500, MAX), false, "can't go under 1 s");
eq(t.remaining, 5000, "and is left alone");
t = { state: "paused", remaining: MAX - 1000, total: 8000, kind: "duration" };
eq(L.adjust(t, 0, 2000, MAX), false, "can't go over the maximum");
t = { state: "ringing", total: 500, endAt: 1, finishedAt: 1, kind: "at" };
eq(L.adjust(t, 5000, 300000, MAX), true, "+5 min on a ringing timer restarts it");
eq([t.state, t.endAt, t.total, t.finishedAt, t.kind], ["running", 305000, 300000, 0, "duration"], "for that duration");
t = { state: "ringing" };
eq(L.adjust(t, 0, -1000, MAX), false, "a ringing timer can't lose time");
eq(L.adjust(t, 0, MAX + 1, MAX), false, "or restart beyond the maximum");

// Restart
t = { state: "ringing", kind: "at", total: 500, endAt: 1, finishedAt: 1, remaining: 0 };
L.restart(t, 1000);
eq([t.kind, t.total, t.endAt, t.remaining, t.state, t.finishedAt], ["duration", 1000, 2000, 1000, "running", 0], "an alarm restarts as a duration of at least 1 s");
t = { state: "ringing", kind: "duration", total: 60000, endAt: 1, finishedAt: 1, remaining: 0 };
L.restart(t, 1000);
eq([t.total, t.endAt], [60000, 61000], "a timer restarts for its full duration");

// Expiry
let r = L.expire([run(1, 1000), run(2, 5000), { id: 3, state: "paused", remaining: 3 }], 2000);
eq(r.fired, true, "a timer ended");
eq(r.list.map(x => x.state), ["ringing", "running", "paused"], "only the ended one rings");
eq([r.list[0].finishedAt, r.list[0].remaining], [1000, 0], "it finished at its end time");
const same = run(2, 5000);
r = L.expire([same], 2000);
eq([r.fired, r.list[0] === same], [false, true], "nothing ended: same objects, nothing fired");
eq(L.expire([run(1, 2000)], 2000).fired, true, "ending exactly now counts");

// The optional tick
eq(L.inFinalSeconds([run(1, 9000)], 0), true, "9 s left: ticking");
eq(L.inFinalSeconds([run(1, 20000)], 0), false, "20 s left: quiet");
eq(L.inFinalSeconds([run(1, 0)], 0), false, "ended: quiet");
eq(L.inFinalSeconds([{ state: "paused", endAt: 5000 }], 0), false, "paused: quiet");

// Next wake-up: the next change of a displayed second
eq(L.nextDelay([], 0), -1, "no timer, no wake-up");
eq(L.nextDelay([{ state: "paused", remaining: 5 }], 0), -1, "everything paused, no wake-up");
eq(L.nextDelay([run(1, 10300)], 0), 300, "the fraction of the second left");
eq(L.nextDelay([run(1, 10000)], 0), 1000, "a whole second when aligned");
eq(L.nextDelay([run(1, 0)], 100), 0, "already ended: now");
eq(L.nextDelay([run(1, 10300), run(2, 5100)], 0), 100, "the soonest of several");
eq(L.nextDelay([{ state: "ringing", finishedAt: 1000 }], 1250), 750, "a ringing timer counts up each second");

// Restore after a restart
const saved = [run(1, 1000), run(2, 500000), { id: 5, state: "ringing", finishedAt: 90000, endAt: 90000 }, null, { label: "no id" }];
const back = L.restore(saved, 3, 100000);
eq(back.list.map(x => x.id), [1, 2, 5], "bad entries are dropped");
eq(back.list[0].state, "ringing", "a timer that ended while off is ringing");
eq(back.nextId, 6, "the next id is past every saved id");
eq(back.ringNow, false, "the one that ended long ago does not sound");
eq(back.recent.map(x => x.id), [5], "only a recently finished one is announced");
eq(L.restore([run(1, 70000)], 1, 100000).ringNow, true, "one that ended 30 s ago sounds");
eq(L.restore("garbage", 4, 0), { list: [], nextId: 4, ringNow: false, recent: [] }, "an unreadable state is empty");
eq(L.restore([run(9, 5000000)], 1, 0).nextId, 10, "the next id never goes back");

done();
