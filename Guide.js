.pragma library
.import "Strings.js" as Strings

// The short notes Sands shows when something cannot be done (value 10:
// never refuse silently). Each note is { title, hint, anchor }: what
// happened, what to do, and the section of docs/GUIDE.md that explains it.
// Pure so tests can check every anchor exists in the guide. `lang` is the
// interface language or locale name (Strings.langOf); English when left out.

// The one place that names the guide; callers add "#" + an anchor.
var URL = "https://github.com/lung595/Sands/blob/main/docs/GUIDE.md";
// The section behind the greyed Edge halo card
var VISUAL_ANCHOR = "visual-alert";

function rangeNote(lang) {
    return { title: Strings.tr("guide.notStarted", lang), hint: Strings.tr("guide.rangeHint", lang), anchor: "syntax" };
}

function fullNote(max, lang) {
    return { title: Strings.tr("guide.notStarted", lang), hint: Strings.tr("guide.fullHint", lang, max), anchor: "syntax" };
}

// « 4x 1h » with only two free places left: two start, and we say so
function partialNote(started, wanted, max, lang) {
    return { title: Strings.tr("guide.partialTitle", lang, started, wanted), hint: Strings.tr("guide.partialHint", lang, max), anchor: "syntax" };
}

// The player failed on the alarm itself, after the paplay fallback
function silentNote(lang) {
    return { title: Strings.tr("guide.silentTitle", lang), hint: Strings.tr("guide.silentHint", lang), anchor: "if-the-alarm-makes-no-sound" };
}

// Settings › Preview could not play the chosen file
function previewNote(lang) {
    return { title: Strings.tr("guide.previewTitle", lang), hint: Strings.tr("guide.previewHint", lang), anchor: "if-the-alarm-makes-no-sound" };
}

// One line for a DMS toast, used when the panel is closed
function toastText(note, lang) {
    return Strings.tr("guide.toast", lang, note.title, note.hint);
}
