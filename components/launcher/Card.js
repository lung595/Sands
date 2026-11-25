.pragma library
.import "../../TimeParser.js" as TP
.import "../../Timers.js" as Timers
.import "../daemon/Snooze.js" as Snooze
.import "../daemon/Notice.js" as Notice

// What a card of the launcher's Timers row writes, as data: the time, the
// end, the short durations, the snooze choices, the rename check, the
// tooltips. Pure, no QML, the time always passed in. The cards
// (SectionCard.qml, ExpandedTimer.qml) only draw it. Tested by
// tests/launcher-card.test.js.

// Time since a ringing timer rang, in ms (0 for any other state)
function overrun(t, now) {
    if (!t || t.state !== "ringing")
        return 0;
    return Math.max(0, now - (t.finishedAt || now));
}

// The time a card shows: the countdown ("12:34"), or for a ringing timer
// the time since it rang, growing ("+0:42")
function clock(t, now) {
    if (!t)
        return "";
    if (t.state === "ringing")
        return "+" + TP.formatClock(overrun(t, now));
    return TP.formatClock(Timers.remainingOf(t, now));
}

// The collapsed card's first line: "Pasta, an em dash, 12:34" (the design's
// separator, written as an escape: no literal dash in the sources)
var SEP = " \u2014 ";
function title(t, now) {
    return t ? Timers.displayLabel(t) + SEP + clock(t, now) : "";
}

// The time of day the timer rings ("18:42"), or rang for a ringing one;
// "" for a paused one (its end is not known)
function endText(t, use24) {
    if (!t || t.state === "paused")
        return "";
    return TP.formatTimeOfDay(t.state === "ringing" ? (t.finishedAt || t.endAt) : t.endAt, use24);
}

// A short duration: "45s", "10m", "1h", "1h30"
function shortDuration(ms) {
    const s = Math.round(Math.max(0, ms || 0) / 1000);
    if (s < 60)
        return s + "s";
    const m = Math.round(s / 60);
    const h = Math.floor(m / 60);
    if (h === 0)
        return m + "m";
    return m % 60 === 0 ? h + "h" : h + "h" + TP.pad(m % 60);
}

// The notice before the end ("2m"), or "" when there is none
function noticeText(minutes) {
    const m = Number(minutes);
    return Number.isFinite(m) && m > 0 ? shortDuration(m * 60000) : "";
}

// The notice this timer gets, in minutes, as the daemon gives it: the
// setting (missing = the 2 min default), 0 when it is off or the timer is
// not longer than the notice
function noticeMinutes(t, setting) {
    const ms = Notice.noticeFromSetting(setting);
    return t && Notice.eligible(t, ms) ? ms / 60000 : 0;
}

// Hover text of the hourglass: when it started and how much is left, the
// only place a percentage is written
function glassTip(t, now, use24) {
    if (!t)
        return "";
    const pct = Math.round(Timers.progressOf(t, now) * 100) + " %";
    if (t.state !== "running" || !(t.total > 0))
        return pct;
    return TP.formatTimeOfDay(t.endAt - t.total, use24) + " → " + TP.formatTimeOfDay(t.endAt, use24) + " · " + pct;
}

// The snooze choices of a ringing card, in minutes, the last one picked
// first: [5, 1, 10]
function snoozeChoices(raw, last) {
    return Snooze.ordered(raw, last).slice(0, 3);
}

// A typed name, cleaned, or "" when it is refused (empty, emoji only)
function cleanName(text) {
    return Timers.stripEmoji(text, TP.MAX_LABEL);
}

// The dots of a plan: [true, true, false…], one per step, done or current
// first. `plan` = { steps, index } (0-based current step); [] without a plan
function planDots(plan) {
    if (!plan || !(plan.steps > 1))
        return [];
    const n = Math.min(12, Math.floor(plan.steps));
    const out = [];
    for (let i = 0; i < n; i++)
        out.push(i <= (plan.index || 0));
    return out;
}

// The prefix DMS puts in front of the item ids ("live:smartTimer:"), so a
// card can name another card of its row
function idPrefix(launcherId, entryId) {
    const full = String(launcherId || "");
    const own = String(entryId || "");
    return own !== "" && full.endsWith(own) ? full.slice(0, full.length - own.length) : "";
}

// The keys of the open card: what a key does there. `focus` is "name"
// (the rename field), "controls" (a button has the keyboard) or "" (the
// search field). Returns "rename", "pause", "stop", "undo" or "" (DMS
// handles the key: Escape collapses, arrows move, letters search).
function keyAction(key, focus, state) {
    if (focus === "name")
        return "";
    if (key === "F2" && state !== "stopped")
        return "rename";
    if (key === "Space" && focus === "controls" && (state === "running" || state === "paused"))
        return "pause";
    return "";
}

// The few words of the cards (names of buttons for tooltips and screen
// readers, the "Stopped · Undo" card), in the DMS language
var WORDS = {
    "en": {
        "others": "Other timers", "stopped": "Stopped", "undo": "Undo",
        "pause": "Pause", "resume": "Resume", "restart": "Restart", "stop": "Stop",
        "collapse": "Close the card", "rename": "Rename", "mute": "Mute this timer", "unmute": "Sound on",
        "ends": "Rings at", "duration": "Duration", "notice": "Notice before the end", "noNotice": "No notice",
        "snooze": "Snooze"
    },
    "fr": {
        "others": "Autres minuteurs", "stopped": "Arrêté", "undo": "Annuler",
        "pause": "Pause", "resume": "Reprendre", "restart": "Relancer", "stop": "Arrêter",
        "collapse": "Refermer la carte", "rename": "Renommer", "mute": "Couper le son de ce minuteur", "unmute": "Remettre le son",
        "ends": "Sonne à", "duration": "Durée", "notice": "Préavis avant la fin", "noNotice": "Pas de préavis",
        "snooze": "Répéter dans"
    }
};

function words(lang) {
    return /^fr/i.test(String(lang || "")) ? WORDS.fr : WORDS.en;
}

// The toast after a stop once the launcher is gone: the name, and the
// command that brings the timer back (DMS shows it with a copy button)
var UNDO_COMMAND = "dms ipc call smartTimer undo";

function stoppedToast(name, lang) {
    return name + " · " + words(lang).stopped;
}
