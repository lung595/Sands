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
