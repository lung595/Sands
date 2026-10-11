.pragma library

// Pure rules for the one-shot « timer finished » event Alex can listen to.
// Sands calls this only when Alex is loaded; nothing here touches the shell.
//
// Delivery: the event goes through setGlobalVar, so a listener gets every
// change, but a reader that loads late only sees the last value. When several
// timers end in the same tick the key is written once per timer, in order.

// The Alex plugin id is a guess until Alex ships its plugin.json (Q148); the
// key is distinct from every other key published through setGlobalVar.
var ALEX_ID = "alex";
var EVENT_KEY = "timerFinished";
var KIND = "timerFinished"; // the discriminator the Alex bridge (NAK-493) accepts
var LABEL_MAX = 60;

// No control characters (they would break a one-line island) and capped.
function cleanLabel(label) {
    if (typeof label !== "string")
        return "";
    return label.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, LABEL_MAX);
}

// A changing id per ring lets a late Alex ignore a stale value; the end time
// is added to the counter so it also differs across a shell restart.
function buildEvent(timer, ringSeq) {
    var at = Number(timer.finishedAt || timer.endAt) || 0;
    return { kind: KIND, id: at + "-" + timer.id + "-" + ringSeq, label: cleanLabel(timer.label), endAt: at };
}

// ---------------------------------------------------------------------------
// « When a Sands timer ends »: the choice Alex owns and Sands only shows.
// Sands keeps no copy and never writes Alex's settings: it asks Alex through
// `dms ipc call` and follows the notice Alex publishes. Nothing here runs by
// itself; the settings page calls it on open, on a click and on a notice.
// ---------------------------------------------------------------------------

// Same words, in the same order, as the row in Alex (D455).
var MODES = [
    { value: "sands", label: "Sands only" },
    { value: "react", label: "Sands + Alex reacts" },
    { value: "alex", label: "Alarm in the Alex island" }
];
var DEFAULT_MODE = "react";
var MODE_CHANGED_KIND = "timerEndModeChanged";
var IPC_FUNCTION = "timerEndMode";

function _known(value) {
    return typeof value === "string" && MODES.some(m => m.value === value);
}

// [{value, label}], fixed words until the contract serves the agent name.
function choices() {
    return MODES.map(m => ({ value: m.value, label: m.label }));
}

// Argument array after `dms`, or null when refused. Reading takes no value.
function readArgs() {
    return ["ipc", "call", ALEX_ID, IPC_FUNCTION];
}

// The value is one of three fixed words, so it is never an option; no `--` is needed.
function setArgs(mode) {
    return _known(mode) ? ["ipc", "call", ALEX_ID, IPC_FUNCTION, mode] : null;
}

// Judges the printed reply, never the exit code: a missing target prints
// « Target not found. » and exits 0. Returns the mode, or "" when unavailable.
function parseReply(output) {
    if (typeof output !== "string" || output.length > 64)
        return "";
    var word = output.trim();
    return _known(word) ? word : "";
}

// The value of the « mode changed » notice, or "" for anything else.
function noticeMode(notice) {
    if (notice === null || typeof notice !== "object" || notice.kind !== MODE_CHANGED_KIND)
        return "";
    return _known(notice.mode) ? notice.mode : "";
}

// What the row shows. `mode` is "" while unread or unreadable. Greyed rows show
// no selection (Q170): Sands rings alone, and the value stays with Alex.
function rowState(alexLoaded, mode) {
    var usable = alexLoaded === true && _known(mode);
    return {
        enabled: usable,
        selected: usable ? mode : "",
        // The D419 chip: only when Alex acts at all.
        batteryChip: usable && mode !== "sands"
    };
}

// Accessible name of the miniature bar under the row, one sentence per situation.
function stripLabel(view) {
    var n = "Alex";
    if (!view.enabled)
        return "Sands chip rings alone. " + n + " is not available.";
    if (view.selected === "sands")
        return "Sands chip rings. " + n + " stays quiet.";
    if (view.selected === "react")
        return "Sands chip rings. " + n + " reacts for 3 seconds.";
    return "Sands chip rings. The " + n + " island shows the alarm with Stop and Snooze.";
}
