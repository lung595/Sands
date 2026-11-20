.pragma library
.import "../../TimeParser.js" as TP
.import "../../Timers.js" as Timers
.import "PlainText.js" as Plain
.import "../../Strings.js" as Strings

// The sentences `dms ipc call smartTimer …` answers. Pure, so a test can
// pin every word a script may parse. Refusals say what to do and link the
// guide section (value 10: never refuse silently). `lang`, last everywhere,
// is the interface language or locale name (Strings.langOf); English when
// left out, which is what scripts get today. The JSON answers stay English.

function tooLong(guideUrl, lang) {
    return Strings.tr("ipc.tooLong", lang, TP.MAX_INPUT, guideUrl);
}

function notUnderstood(guideUrl, lang) {
    return Strings.tr("ipc.notUnderstood", lang, guideUrl);
}

// `r` is a parsed request with `started` set to how many timers really
// started; `refusal` is the note explaining why none did.
function started(r, refusal, maxTimers, guideUrl, use24h, lang) {
    if (r.started === 0)
        return Strings.tr("ipc.refused", lang, refusal.hint, guideUrl, refusal.anchor);
    const partial = r.started < (r.count || 1);
    const times = partial ? Strings.tr("ipc.partialCount", lang, r.started, r.count) : (r.kind === "duration" && r.count > 1 ? r.count + " × " : "");
    const limit = partial ? Strings.tr("ipc.limit", lang, maxTimers, guideUrl) : "";
    const name = Plain.plain(r.label || Strings.tr(r.kind === "at" ? "name.alarm" : "name.timer", lang));
    const what = r.kind === "at" ? Strings.tr("ipc.startedAt", lang, TP.formatTimeOfDay(r.at, use24h)) : TP.formatHuman(r.ms);
    return Strings.tr("ipc.started", lang, times, name, what, limit);
}

function notChanged(guideUrl, lang) {
    return Strings.tr("ipc.notChanged", lang, guideUrl);
}

// `smartTimer undo`: the timer stopped last is back, or it is too late
function undone(lang) {
    return Strings.tr("ipc.undone", lang);
}

function nothingToUndo(lang) {
    return Strings.tr("ipc.nothingToUndo", lang);
}

// One line per timer, "label<TAB>mm:ss", already in display order
function list(sortedTimers, now, lang) {
    if (sortedTimers.length === 0)
        return Strings.tr("ipc.noTimer", lang);
    return sortedTimers.map(t => {
        const state = t.state === "paused" ? Strings.tr("ipc.paused", lang) : (t.state === "ringing" ? Strings.tr("ipc.done", lang) : "");
        const name = t.label ? Timers.displayLabel(t) : Strings.tr(t.kind === "at" ? "name.alarm" : "name.timer", lang);
        return Plain.plain(name) + "\t" + TP.formatClock(Timers.remainingOf(t, now)) + state;
    }).join("\n");
}

// JSON answers of `smartTimer snooze`, like `status`: always parseable
function snoozed(minutes) {
    return JSON.stringify({ snoozed: true, minutes: minutes });
}

function notRinging() {
    return JSON.stringify({ snoozed: false, reason: "nothing is ringing" });
}

// `diagnostics` answers: the first starts the report, the next hands it over
function collecting(guideUrl, lang) {
    return Strings.tr("ipc.collecting", lang, guideUrl);
}

function stillCollecting(guideUrl, lang) {
    return Strings.tr("ipc.stillCollecting", lang, guideUrl);
}
