.pragma library

// Pure rules for the one-shot « timer finished » event Alex can listen to.
// Sands calls this only when Alex is loaded; nothing here touches the shell.

// The Alex plugin id and the key Sands writes under its own id. The key is
// distinct from every other key published through setGlobalVar.
var ALEX_ID = "alex";
var EVENT_KEY = "timerFinished";
var CHOICE_KEY = "sandsAlarm";
var LABEL_MAX = 60;

// A changing id per ring lets a late Alex ignore a stale value; the end time
// is added to the counter so it also differs across a shell restart.
function buildEvent(timer, ringSeq) {
    var label = typeof timer.label === "string" ? timer.label.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, LABEL_MAX) : "";
    var at = Number(timer.finishedAt || timer.endAt) || 0;
    return { id: at + "-" + timer.id + "-" + ringSeq, label: label, endAt: at };
}

// True only for the explicit choice « alarm in the Alex island »; anything
// else, including a failed read, keeps Sands' own alarm.
function alexShowsAlarm(choice) {
    return choice === "island";
}
