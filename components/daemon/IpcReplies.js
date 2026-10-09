.pragma library
.import "../../TimeParser.js" as TP
.import "../../Timers.js" as Timers

// The sentences `dms ipc call smartTimer …` answers. Pure, so a test can
// pin every word a script may parse. Refusals say what to do and link the
// guide section (value 10: never refuse silently).

function tooLong(guideUrl) {
    return "Not started: keep it under " + TP.MAX_INPUT + " characters, like \"12 min pasta\": " + guideUrl + "#syntax";
}

function notUnderstood(guideUrl) {
    return "Not started. Try \"12 min pasta\": " + guideUrl + "#syntax";
}

// `r` is a parsed request with `started` set to how many timers really
// started; `refusal` is the note explaining why none did.
function started(r, refusal, maxTimers, guideUrl, use24h) {
    if (r.started === 0)
        return "Not started: " + refusal.hint + ". " + guideUrl + "#" + refusal.anchor;
    const partial = r.started < (r.count || 1);
    const times = partial ? r.started + " of " + r.count + " × " : (r.kind === "duration" && r.count > 1 ? r.count + " × " : "");
    const limit = partial ? " (at most " + maxTimers + " at once: " + guideUrl + "#syntax)" : "";
    return "Started: " + times + (r.label || (r.kind === "at" ? "Alarm" : "Timer")) + " — " + (r.kind === "at" ? "at " + TP.formatTimeOfDay(r.at, use24h) : TP.formatHuman(r.ms)) + limit;
}

function notChanged(guideUrl) {
    return "Not changed: a timer lasts between 1 second and 100 hours. " + guideUrl + "#syntax";
}

// One line per timer, "label<TAB>mm:ss", already in display order
function list(sortedTimers, now) {
    if (sortedTimers.length === 0)
        return "No timer";
    return sortedTimers.map(t => {
        const state = t.state === "paused" ? " (paused)" : (t.state === "ringing" ? " (done)" : "");
        return Timers.displayLabel(t) + "\t" + TP.formatClock(Timers.remainingOf(t, now)) + state;
    }).join("\n");
}
