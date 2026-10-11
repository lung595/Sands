.pragma library

// The short notes Sands shows when something cannot be done (value 10:
// never refuse silently). Each note is { title, hint, anchor }: what
// happened, what to do, and the section of docs/GUIDE.md that explains it.
// Pure so tests can check every anchor exists in the guide.

// The one place that names the guide; callers add "#" + an anchor.
var URL = "https://github.com/lung595/Sands/blob/main/docs/GUIDE.md";
// The section behind the greyed « when a timer ends » row
var ALEX_ANCHOR = "alex";
// The section behind the greyed Edge halo card
var VISUAL_ANCHOR = "visual-alert";

function rangeNote() {
    return { title: "Not started", hint: "A timer lasts between 1 second and 100 hours", anchor: "syntax" };
}

function fullNote(max) {
    return { title: "Not started", hint: "At most " + max + " timers at once: cancel one first", anchor: "syntax" };
}

// « 4x 1h » with only two free places left: two start, and we say so
function partialNote(started, wanted, max) {
    return { title: "Started " + started + " of " + wanted, hint: "At most " + max + " timers run at once", anchor: "syntax" };
}

// The player failed on the alarm itself, after the paplay fallback
function silentNote() {
    return { title: "The alarm made no sound", hint: "Pick another sound in the settings", anchor: "if-the-alarm-makes-no-sound" };
}

// Settings › Preview could not play the chosen file
function previewNote() {
    return { title: "Could not play this sound", hint: "Check the file path, or pick another sound", anchor: "if-the-alarm-makes-no-sound" };
}

// One line for a DMS toast, used when the panel is closed
function toastText(note) {
    return "Sands: " + note.title + ". " + note.hint;
}
