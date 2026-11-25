// Judge of tests/qml-daemon/run.sh (gjs -m). Reads what the three daemon runs
// reported ("sands-e2e" lines), what the stand-ins on PATH recorded (one tab-
// separated line per call) and the journal files the runs left.
//   check.js state <dir>    the plugin state the "ring" run saved, as JSON
//   check.js wait <dir>     seconds to wait until Rice has ended (for sleep)
//   check.js verify <dir>   every assertion; exit 1 when one fails
import GLib from "gi://GLib";
import System from "system";

const [mode, dir] = System.programArgs;

function read(name) {
    const [ok, bytes] = GLib.file_get_contents(dir + "/log/" + name);
    return ok ? new TextDecoder().decode(bytes) : "";
}

function tryRead(name) {
    try {
        return read(name);
    } catch (e) {
        return null;
    }
}

// [{ what, value }] in order, from "<what> <json>" lines
function lines(phase) {
    return read(phase + ".lines").split("\n").filter(l => l !== "").map(l => {
        const cut = l.indexOf(" ");
        return { what: l.slice(0, cut), value: JSON.parse(l.slice(cut + 1)) };
    });
}

function first(list, what) {
    const l = list.find(x => x.what === what);
    return l ? l.value : undefined;
}

// The last value saved for each plugin state key
function savedState(list) {
    const state = {};
    list.filter(l => l.what === "save").forEach(l => state[l.value.key] = l.value.value);
    return state;
}

// [{ at, tool, args }]
function calls(phase) {
    return read(phase + ".calls").split("\n").filter(l => l !== "").map(l => {
        const f = l.split("\t");
        return { at: Number(f[0]), tool: f[1], args: f.slice(2) };
    });
}

const byId = (list, id) => (list || []).find(t => t.id === id);

if (mode === "state" || mode === "wait") {
    const list = lines("ring");
    if (!first(list, "final")) {
        const error = first(list, "error");
        printerr("FAIL ring run did not finish" + (error ? ": " + error : first(list, "timeout") ? " (no ring within 15 s)" : ""));
        System.exit(1);
    }
    const state = savedState(list);
    if (mode === "state") {
        print(JSON.stringify(state));
    } else {
        const rice = byId(state.timers, 2);
        print((Math.max(0, (rice ? rice.endAt : 0) + 400 - Date.now()) / 1000).toFixed(3));
    }
    System.exit(0);
}

let failed = 0;
function check(name, ok, detail) {
    if (ok) {
        print("ok " + name);
    } else {
        failed++;
        print("FAIL " + name + (detail === undefined ? "" : ": " + JSON.stringify(detail)));
    }
}

// Script errors of a run (ReferenceError, TypeError...), colours stripped: a
// broken binding or handler must fail even when the reported facts look right
function scriptErrors(phase) {
    return read(phase + ".out").split("\n").map(l => l.replace(/\x1b\[[0-9;]*m/g, "")).filter(l => /: [A-Za-z]*Error: /.test(l));
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const near = (a, b, slack) => Math.abs(a - b) <= slack;

const RING_FILE = dir + "/tree/sounds/hourglass.ogg";
const notifyArgs = (name, body) => ["-a", "Sands", "-i", "alarm-symbolic", "-u", "critical", "-p", "-A", "stop=Stop", "-A", "snooze=+5 min", name + " - done", body];
const TEA_NOTE = notifyArgs("Tea", "2 s elapsed");
const RICE_NOTE = notifyArgs("Rice", "8 s elapsed");
const closeArgs = id => ["call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification", String(id)];
// 80 % volume, rising alarm: 30 %, 65 %, then full
const RAMP = ["0.24", "0.52", "0.80"];

function rampOk(plays) {
    return plays.length > 0 && plays.every((c, i) => same(c.args, ["--volume=" + RAMP[Math.min(i, 2)], "--", RING_FILE]));
}

function others(list, tools) {
    return list.filter(c => tools.indexOf(c.tool) < 0).map(c => c.tool);
}

// ---------------------------------------------------------------- ring run
const ring = lines("ring");
const ringCalls = calls("ring");
const begin = first(ring, "begin");
const rang = ring.find(l => l.what === "ringing" && l.value.ringing);
const rFinal = first(ring, "final");
check("ring: no script error in the run", scriptErrors("ring").length === 0, scriptErrors("ring"));
check("ring: finished without the 15 s guard", rFinal !== undefined && !first(ring, "timeout"));
check("ring: the daemon rang", rang !== undefined);
if (!rang || !rFinal)
    System.exit(1);

const tea = byId(rang.value.timers, 1);
const endAt = tea.endAt;
check("ring: Tea ends 2 s after its start", near(endAt, begin + 2000, 20) && tea.total === 2000, tea);
check("ring: Tea rings on time, finishedAt = endAt", tea.state === "ringing" && tea.finishedAt === endAt && tea.remaining === 0 && rang.value.at >= endAt && rang.value.at - endAt < 1000, { at: rang.value.at, tea: tea });
check("ring: only Tea rings", rang.value.timers.filter(t => t.state === "ringing").length === 1, rang.value.timers);
const rangs = ring.filter(l => l.what === "rang").map(l => l.value);
check("ring: one rang signal, for Tea alone", rangs.length === 1 && same(rangs[0].ids, [1]), rangs);

// The dune: { name, reason } of the scene on screen, null at rest
const DUNE = name => ({ name: name, reason: "Click to stop" });
const started = first(ring, "started");
check("ring: no dune before the end", started && started.alert === false && started.dune === null, started && [started.alert, started.dune]);
// The dune rises on `rang`, right after the list changed
const rose = ring.find(l => l.what === "rang");
check("ring: the dune rises at the ring, named Tea", rose !== undefined && rose.value.alert === true && same(rose.value.dune, DUNE("Tea")) && rose.value.at - rang.value.at < 100, rose && [rose.value.alert, rose.value.dune]);

const notes = ringCalls.filter(c => c.tool === "notify-send");
check("ring: one notification, exact argv", notes.length === 1 && same(notes[0].args, TEA_NOTE), notes);
check("ring: notification at the ring", notes.length === 1 && notes[0].at >= endAt && notes[0].at - endAt < 1000, notes.map(c => c.at - endAt));

const plays = ringCalls.filter(c => c.tool === "pw-play");
check("ring: pw-play plays the default ring with the rising volume", plays.length >= 2 && rampOk(plays), plays.map(c => c.args));
check("ring: no sound before the end (no tick by default)", plays.length > 0 && plays[0].at >= endAt && plays[0].at - endAt < 1000, plays.map(c => c.at - endAt));
check("ring: the alarm repeats after a 450 ms gap", plays.length >= 2 && plays[1].at - plays[0].at >= 1400 && plays[1].at - plays[0].at < 2500, plays.map(c => c.at));
check("ring: nothing else runs (paplay, clipboard, dms, niri, gdbus)", others(ringCalls, ["pw-play", "notify-send"]).length === 0, others(ringCalls, ["pw-play", "notify-send"]));
check("ring: no other plugin is told", ring.every(l => l.what !== "global"));
check("ring: still ringing with sound at the end", rFinal.ringing && rFinal.soundActive);
check("ring: the dune stays up while Tea rings", rFinal.alert === true && same(rFinal.dune, DUNE("Tea")), [rFinal.alert, rFinal.dune]);

const state = savedState(ring);
const sTimers = state.timers || [];
const rice = byId(sTimers, 2);
const bread = byId(sTimers, 3);
const soup = byId(sTimers, 4);
check("ring: saved Tea is ringing", same(byId(sTimers, 1), tea), sTimers);
check("ring: saved Rice still runs, 8 s", rice && rice.label === "Rice" && rice.state === "running" && rice.total === 8000 && near(rice.endAt, begin + 8000, 20) && rice.hue === 1, rice);
check("ring: saved Bread runs, 1 h", bread && bread.label === "Bread" && bread.state === "running" && bread.total === 3600000 && near(bread.endAt, begin + 3600000, 20) && bread.hue === 2, bread);
check("ring: saved Soup is paused with its time left", soup && soup.label === "Soup" && soup.state === "paused" && soup.remaining <= 600000 && soup.remaining > 599000 && soup.hue === 3, soup);
check("ring: saved exactly four timers, next id 5", sTimers.length === 4 && state.nextId === 5, { n: sTimers.length, nextId: state.nextId });
check("ring: recents keep the four durations", same((state.recents || []).map(r => [r.ms, r.label, r.uses]).sort((a, b) => a[0] - b[0]), [[2000, "Tea", 1], [8000, "Rice", 1], [600000, "Soup", 1], [3600000, "Bread", 1]]), state.recents);
check("ring: the old end modes and end actions are dropped once, the rest kept", same(first(ring, "settings"), { settings: { smartTimer: { hourglassStyle: "classic" }, other: { endMode: "keep" } }, saves: 1 }), first(ring, "settings"));
check("ring: one toast, the end actions are gone", same(first(ring, "toasts"), [{ message: "End actions removed", level: 0 }]), first(ring, "toasts"));
check("ring: the removal is noted once in the plugin state", same(ring.filter(l => l.what === "save" && l.value.key === "endActionsRetired").map(l => l.value.value), [true]), ring.filter(l => l.what === "save" && l.value.key === "endActionsRetired"));
check("ring: launcher works without a prefix (noTrigger saved)", ring.some(l => l.what === "data" && l.value.key === "noTrigger" && l.value.value === true));

const journal = tryRead("ring.history");
let records = null;
try {
    records = JSON.parse(journal).records;
} catch (e) {}
check("ring: the journal holds one line for Tea", same(records, [{ name: "Tea", start: endAt - 2000, end: endAt }]), journal);
check("ring: journal folder 0700, file 0600", same((tryRead("modes") || "").trim().split("\n"), ["700", "600"]), tryRead("modes"));
const week = first(ring, "week") || [];
check("ring: the week shows Tea, 2 s", week.length === 1 && week[0].name === "Tea" && week[0].ms === 2000, week);

// ------------------------------------------------------------- restore run
const back = lines("restore");
const backCalls = calls("restore");
const restored = first(back, "restored");
const stopTea = first(back, "stopTea");
const stopAll = first(back, "stopAll");
const bFinal = first(back, "final");
check("restore: no script error in the run", scriptErrors("restore").length === 0, scriptErrors("restore"));
check("restore: finished without the 15 s guard", bFinal !== undefined && !first(back, "timeout"));
if (!restored || !stopTea || !stopAll || !bFinal)
    System.exit(1);

check("restore: Rice ended while no shell ran", rice.endAt < restored.at, { endAt: rice.endAt, restoredAt: restored.at });
const rRice = byId(restored.timers, 2);
check("restore: Rice comes back ringing since its end", rRice && rRice.state === "ringing" && rRice.finishedAt === rice.endAt && rRice.remaining === 0 && same(Object.assign({}, rRice, { state: "running", finishedAt: 0, remaining: 8000 }), rice), rRice);
check("restore: Tea, Bread and Soup come back as saved", same(restored.timers.filter(t => t.id !== 2 && t.id !== 0), sTimers.filter(t => t.id !== 2)), restored.timers);
check("restore: the daemon rings", restored.ringing === true);
const bRangs = back.filter(l => l.what === "rang").map(l => l.value);
check("restore: one rang for Tea and Rice, latest last, not for Pasta", bRangs.length === 1 && same(bRangs[0].ids, [1, 2]), bRangs.map(r => r.ids));
check("restore: the dune comes back, named after the last to end (Rice)", bRangs.length === 1 && bRangs[0].alert === true && same(bRangs[0].dune, DUNE("Rice")) && bRangs[0].at - restored.at < 500, bRangs[0] && [bRangs[0].alert, bRangs[0].dune]);
// Pasta ended 8 h before: over the 5 min of the sleep rule
const pastaEnd = first(back, "pasta");
const rPasta = byId(restored.timers, 0);
check("restore: Pasta, ended 8 h ago, stays in the list as done", typeof pastaEnd === "number" && rPasta && rPasta.state === "ringing" && rPasta.finishedAt === pastaEnd, rPasta);
// The ended ones are saved as ringing at once: a second restart (before any
// other change) neither journals nor announces them again
const firstSave = back.find(l => l.what === "save" && l.value.key === "timers");
const fsList = firstSave ? firstSave.value.value : [];
check("restore: saved at once with Rice and Pasta ringing", firstSave !== undefined && byId(fsList, 2) && byId(fsList, 2).state === "ringing" && byId(fsList, 0) && byId(fsList, 0).state === "ringing", firstSave && [fsList.map(t => [t.id, t.state])]);

const staleNotes = backCalls.filter(c => c.tool === "notify-send" && c.args.indexOf("-p") < 0);
check("restore: Pasta gets one quiet note, its end time, no button", staleNotes.length === 1 && same(staleNotes[0].args.slice(0, 4), ["-a", "Sands", "-i", "alarm-symbolic"]) && staleNotes[0].args.length === 5 && /^Pasta finished at \d{1,2}:\d{2}( [AP]M)?$/.test(staleNotes[0].args[4]), staleNotes.map(c => c.args));
const bNotes = backCalls.filter(c => c.tool === "notify-send" && c.args.indexOf("-p") >= 0).sort((a, b) => a.args[11] < b.args[11] ? 1 : -1);
check("restore: Tea and Rice are notified again, exact argv", bNotes.length === 2 && same(bNotes.map(c => c.args), [TEA_NOTE, RICE_NOTE]) && bNotes.every(c => c.at < stopTea.at), bNotes);
const bPlays = backCalls.filter(c => c.tool === "pw-play");
check("restore: the alarm starts again from 30 %", bPlays.length >= 1 && rampOk(bPlays) && bPlays[0].at - restored.at < 1000, bPlays.map(c => [c.at - restored.at].concat(c.args)));

check("restore: a new timer takes the next id (5)", first(back, "egg") === 5, first(back, "egg"));
check("restore: stopping Tea is accepted", stopTea.done === true && !byId(stopTea.timers, 1));
const closes = backCalls.filter(c => c.tool === "gdbus");
const teaClose = closes.filter(c => c.at >= stopTea.at && c.at < stopAll.at);
check("restore: stopping Tea closes its notification only (42)", teaClose.length === 1 && same(teaClose[0].args, closeArgs(42)), closes);
check("restore: Rice still rings with sound after Tea's stop", stopTea.ringing === true && stopTea.soundActive === true && stopAll.soundActive === true, { stopTea: stopTea.soundActive, stopAll: stopAll.soundActive });
check("restore: the dune stays up for Rice after Tea's stop", stopTea.alert === true && same(stopTea.dune, DUNE("Rice")) && stopAll.alert === true && same(stopAll.dune, DUNE("Rice")), { stopTea: stopTea.dune, stopAll: stopAll.dune });
const unrang = back.find(l => l.what === "ringing" && !l.value.ringing);
check("restore: the dune's click stops the ring and takes the dune down", unrang !== undefined && unrang.value.at - stopAll.at < 100 && unrang.value.alert === false && unrang.value.dune === null, unrang && unrang.value);
const allClose = closes.filter(c => c.at >= stopAll.at);
check("restore: the last stop closes Rice's notification (43)", allClose.length === 1 && same(allClose[0].args, closeArgs(43)) && closes.length === 2, closes);
check("restore: no sound after the last stop", bPlays.every(c => c.at <= stopAll.at + 100), bPlays.map(c => c.at - stopAll.at));
check("restore: nothing else runs", others(backCalls, ["pw-play", "notify-send", "gdbus"]).length === 0, others(backCalls, ["pw-play", "notify-send", "gdbus"]));
check("restore: clean settings are not written again", same(first(back, "settings"), { settings: { smartTimer: { hourglassStyle: "classic" } }, saves: 0 }), first(back, "settings"));
check("restore: no other plugin is told", back.every(l => l.what !== "global"));
check("restore: no toast, the end actions were told once already", same(first(back, "toasts"), []), first(back, "toasts"));
check("restore: the flag is not written again", back.every(l => !(l.what === "save" && l.value.key === "endActionsRetired")));

const left = bFinal.timers;
const egg = byId(left, 5);
check("restore: Bread and Soup untouched, Tea and Rice gone", same(left.filter(t => t.id !== 5), [bread, soup]), left);
check("restore: Egg runs for 5 min", egg && egg.label === "Egg" && egg.state === "running" && egg.total === 300000, egg);
check("restore: silent and not ringing after the stops", bFinal.ringing === false && bFinal.soundActive === false, bFinal);
check("restore: no dune after the last stop", bFinal.alert === false && bFinal.dune === null, [bFinal.alert, bFinal.dune]);
const bState = savedState(back);
check("restore: saved state follows (next id 6)", same(bState.timers, left) && bState.nextId === 6, bState);
check("restore: Rice's old end action is gone everywhere", restored.timers.concat(bFinal.timers, bState.timers || []).every(t => !("actionId" in t)), restored.timers);

// Every timer that ended gets its journal line once: Rice and Pasta ended
// while no shell ran, Tea's line is not written again, the stops add nothing
let bRecords = null;
try {
    bRecords = JSON.parse(tryRead("restore.history")).records;
} catch (e) {}
const lineOf = (name, end, ms) => ({ name: name, start: end - ms, end: end });
check("restore: the journal gains Rice and Pasta, once each", same((bRecords || []).slice().sort((a, b) => a.end - b.end), [lineOf("Pasta", pastaEnd, 600000), { name: "Tea", start: endAt - 2000, end: endAt }, lineOf("Rice", rice.endAt, 8000)]), bRecords);
check("restore: the week shows Rice too", (first(back, "week") || []).some(w => w.name === "Rice" && w.ms === 8000) && (first(back, "week") || []).some(w => w.name === "Tea"), first(back, "week"));

// ---------------------------------------------------------------- mute run
const mute = lines("mute");
const muteCalls = calls("mute");
const mBegin = first(mute, "begin");
const mStarted = first(mute, "started");
const mStopBread = first(mute, "stopBread");
const mUndoBread = first(mute, "undoBread");
const mStopSoup = first(mute, "stopSoup");
const mRang = mute.find(l => l.what === "ringing" && l.value.ringing);
const mPause = first(mute, "pauseAll");
const mResume = first(mute, "resumeAll");
const mLate = first(mute, "lateUndo");
const mFinal = first(mute, "final");
check("mute: no script error in the run", scriptErrors("mute").length === 0, scriptErrors("mute"));
check("mute: finished without the 15 s guard", mFinal !== undefined && !first(mute, "timeout"));
if (!mStarted || !mStopBread || !mUndoBread || !mStopSoup || !mRang || !mPause || !mResume || !mLate || !mFinal)
    System.exit(1);

const [MINT, BREAD, SOUP] = mStarted.ids;
check("mute: three timers, ids 1 to 3", same(mStarted.ids, [1, 2, 3]), mStarted.ids);
check("mute: Mint is muted, and saved so", mStarted.muted === true && byId(mStarted.timers, MINT).muted === true, byId(mStarted.timers, MINT));
check("mute: rename drops the emoji", mStarted.rename === true && byId(mUndoBread.timers, BREAD).label === "Pain frais", byId(mUndoBread.timers, BREAD));
check("mute: a name of emoji only is refused", mStarted.renameEmpty === false && byId(mStopBread.timers, SOUP).label === "Soup", byId(mStopBread.timers, SOUP));
check("mute: stopping Bread keeps it for undo", mStopBread.done === true && !byId(mStopBread.timers, BREAD) && same(mStopBread.removed, [BREAD]), mStopBread);
check("mute: undo brings Bread back as it was, once", mUndoBread.done === true && mUndoBread.again === false && same(mUndoBread.removed, []) && byId(mUndoBread.timers, BREAD).endAt === byId(mStarted.timers, BREAD).endAt, mUndoBread);
check("mute: Soup stopped, waiting for an undo", mStopSoup.done === true && !byId(mStopSoup.timers, SOUP) && same(mStopSoup.removed, [SOUP]), mStopSoup);

const mint = byId(mRang.value.timers, MINT);
check("mute: Mint rings on time", mint && mint.state === "ringing" && mint.muted === true && mRang.value.at - mint.endAt < 1000 && near(mint.endAt, mBegin + 2000, 30), mRang.value);
check("mute: no sound for a muted ring", mRang.value.soundActive === false && mPause.soundActive === false, [mRang.value.soundActive, mPause.soundActive]);
const mRose = first(mute, "rang");
check("mute: the dune still rises, named Mint", mRose !== undefined && same(mRose.ids, [MINT]) && mRose.alert === true && same(mRose.dune, { name: "Mint", reason: "Sound is muted" }), mRose && [mRose.alert, mRose.dune]);
const mNotes = muteCalls.filter(c => c.tool === "notify-send");
check("mute: the notification still comes", mNotes.length === 1 && same(mNotes[0].args, notifyArgs("Mint", "2 s elapsed")), mNotes.map(c => c.args));
check("mute: no player ever runs", muteCalls.every(c => c.tool !== "pw-play" && c.tool !== "paplay"), muteCalls.map(c => c.tool));

check("mute: pause all pauses Bread alone (Mint rings), then nothing", mPause.paused === 1 && mPause.again === 0 && byId(mPause.timers, BREAD).state === "paused" && byId(mPause.timers, MINT).state === "ringing", mPause);
check("mute: resume all resumes it", mResume.resumed === 1 && byId(mResume.timers, BREAD).state === "running", mResume);
check("mute: Soup's undo is refused after 5 s, and forgotten", mLate.done === false && !byId(mLate.timers, SOUP) && same(mLate.removed, []) && mLate.at - mStopSoup.at >= 5000, mLate);

// timersChanged: one per action, none from the clock
const changes = mute.filter(l => l.what === "changed").map(l => l.value);
const quiet = changes.filter(at => at > mStopSoup.at + 50 && at < mRang.value.at - 50);
check("mute: no list change while the clock runs (before the ring)", quiet.length === 0 && mRang.value.at - mStopSoup.at > 1000, changes.map(at => at - mBegin));
const ringChanges = changes.filter(at => at >= mRang.value.at - 50 && at < mPause.at - 50);
check("mute: one list change at the ring, none during the ring", ringChanges.length === 1, changes.map(at => at - mBegin));
const actionChanges = changes.filter(at => at <= mStopSoup.at + 50);
// Mint, mute, Bread, Soup, rename, stop Bread, undo, stop Soup; the refused rename and undo change nothing
check("mute: one list change per accepted action", actionChanges.length === 8, actionChanges.length);
const pauseChanges = changes.filter(at => at >= mPause.at - 50 && at <= mLate.at + 50);
check("mute: pause all and resume all change the list once each", pauseChanges.length === 2, changes.map(at => at - mBegin));
// The launcher refresh: never on a DMS that has not asked for the Timers row
// (it declares the signal too and would run the open search again), then
// once per list change
const updates = phase => lines(phase).filter(l => l.what === "launcherUpdate").length;
check("ring and restore: no launcher refresh without live sections", updates("ring") === 0 && updates("restore") === 0, [updates("ring"), updates("restore")]);
const liveAt = mute.findIndex(l => l.what === "live");
const muteBefore = mute.slice(0, Math.max(liveAt, 0));
const muteAfter = liveAt < 0 ? [] : mute.slice(liveAt);
check("mute: no launcher refresh before DMS asks for the row", liveAt > 0 && muteBefore.every(l => l.what !== "launcherUpdate"), muteBefore.filter(l => l.what === "launcherUpdate").length);
const refreshes = muteAfter.filter(l => l.what === "launcherUpdate");
check("mute: then one refresh per list change, for smartTimer", refreshes.length === 2 && refreshes.length === muteAfter.filter(l => l.what === "changed").length && refreshes.every(l => l.value === "smartTimer"), refreshes);
check("mute: the muted state is saved", (savedState(mute).timers || []).some(t => t.id === MINT && t.muted === true), savedState(mute).timers);

print(failed === 0 ? "daemon e2e: all checks passed" : "daemon e2e: " + failed + " check(s) failed");
System.exit(failed === 0 ? 0 : 1);
