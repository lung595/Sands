.pragma library
.import "../../TimeParser.js" as TP
.import "PlainText.js" as Plain

// Pure parts of the end-of-timer notification: what it says, the command
// that shows it, the command that closes it, and what its output means.

var CLOSE_COMMAND_HEAD = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification"];

function body(t, use24h) {
    return t.kind === "at" ? "It's " + TP.formatTimeOfDay(t.endAt, use24h) : TP.formatHuman(t.total) + " elapsed";
}

// notify-send waits for the user's choice and prints the notification id,
// then the action chosen ("stop" or "snooze")
function showCommand(label, bodyText) {
    return ["notify-send", "-a", "Sands", "-i", "alarm-symbolic", "-u", "critical", "-p", "-A", "stop=Stop", "-A", "snooze=+5 min", Plain.plain(label) + " - done", bodyText];
}

// A timer that ended long ago, while the machine slept or the shell was off:
// a plain note, no buttons, nobody waits for an answer ("Pasta finished at 02:14")
function staleCommand(label, finishedAt, use24h) {
    return ["notify-send", "-a", "Sands", "-i", "alarm-symbolic", Plain.plain(label) + " finished at " + TP.formatTimeOfDay(finishedAt, use24h)];
}

function closeCommand(notifId) {
    return CLOSE_COMMAND_HEAD.concat([String(notifId)]);
}

// One line of notify-send output: { id } for the notification id,
// { action } for a button, null for anything else
function parseLine(line) {
    const v = line.trim();
    if (/^\d+$/.test(v))
        return { id: parseInt(v) };
    if (v === "stop" || v === "snooze")
        return { action: v };
    return null;
}
