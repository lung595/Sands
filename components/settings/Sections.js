.pragma library

// The settings page as data: the sections in order and every setting filed
// under one. The view draws this table and the search indexes it; renaming or
// moving a section is a one-line change here. Pure, no state, no side effect.
// Tested by tests/settings-sections.test.js.
//
// A setting is { key, section, label, help, words[], default?, level?, cost?, pending? }:
//   words    search synonyms, English and French
//   level    battery level when the setting has a real cost: "high" | "some" | "light"
//   cost     one line saying what the cost is (set with `level`)
//   pending  the feature is not merged yet: the view hides it until the flag is dropped

// Order is the order of the rail. A section without a visible setting is hidden.
var SECTIONS = [
    { "id": "timers", "label": "Timers" },
    { "id": "focus", "label": "Focus & chains" },
    { "id": "appearance", "label": "Appearance" },
    { "id": "effects", "label": "Effects & battery" },
    { "id": "bar", "label": "Bar" },
    { "id": "desktop", "label": "Desktop" },
    { "id": "alerts", "label": "Alerts & sounds" },
    { "id": "advanced", "label": "Advanced" },
    { "id": "help", "label": "Help" }
];

var SETTINGS = [
    // Timers
    { "key": "noTrigger", "section": "timers", "label": "Automatic detection", "default": true,
      "help": "Understands “timer 20 min”, “25m pasta” or “at 6pm” without a prefix",
      "words": ["launcher", "prefix", "detect", "lanceur", "détection", "automatique", "préfixe"] },
    { "key": "trigger", "section": "timers", "label": "Prefix", "default": "timer",
      "help": "The word to type first when automatic detection is off",
      "words": ["trigger", "keyword", "mot", "déclencheur", "préfixe"] },
    { "key": "snooze", "section": "timers", "label": "Snooze choices", "pending": true,
      "help": "The delays offered when a timer rings",
      "words": ["postpone", "delay", "répéter", "reporter", "rappel"] },
    { "key": "noticeBefore", "section": "timers", "label": "Notice before the end", "pending": true,
      "help": "A quiet heads-up before a long timer ends",
      "words": ["warning", "reminder", "heads-up", "préavis", "avertissement", "avant la fin"] },

    // Appearance
    { "key": "lookPreset", "section": "appearance", "label": "Look", "pending": true,
      "help": "Fil, Pivot or your own mix",
      "words": ["preset", "style", "theme", "apparence", "préréglage", "fil", "pivot"] },
    { "key": "hourglassStyle", "section": "appearance", "label": "Hourglass", "default": "classic",
      "help": "Only the hourglass changes: sand, freeze and flip stay the same",
      "words": ["glass of time", "sablier", "classic", "classique", "sand", "sable"] },

    // Alerts and sounds
    { "key": "visualAlert", "section": "alerts", "label": "Visual alert", "pending": true,
      "help": "How the pill shows that a timer ended",
      "words": ["flash", "pulse", "alerte", "visuelle", "fin"] },
    { "key": "sound", "section": "alerts", "label": "Sound", "default": "default",
      "help": "Loops when a timer reaches zero",
      "words": ["alarm", "ring", "tone", "son", "sonnerie", "alarme"] },
    { "key": "customSound", "section": "alerts", "label": "Sound file", "default": "",
      "help": "Full path to an .oga, .ogg, .wav, .mp3 or .flac file",
      "words": ["custom", "file", "path", "fichier", "chemin", "personnalisé"] },
    { "key": "volume", "section": "alerts", "label": "Volume", "default": 80,
      "help": "How loud the alarm rings",
      "words": ["loud", "level", "volume sonore", "niveau", "fort"] },
    { "key": "rampUp", "section": "alerts", "label": "Gentle alarm", "default": true,
      "help": "Starts softly, then rises to the chosen volume",
      "words": ["fade", "soft", "progressive", "doux", "progressif", "crescendo"] },
    { "key": "ringDuration", "section": "alerts", "label": "Alarm duration", "default": 60,
      "help": "The sound stops by itself after this delay; the pill keeps pulsing until you stop it",
      "words": ["length", "stop", "durée", "arrêt", "sonnerie"] },
    { "key": "tick", "section": "alerts", "label": "Final countdown ticks", "default": false,
      "help": "A soft tick on each of the last 10 seconds",
      "level": "some", "cost": "Plays a sound on each of the last 10 seconds",
      "words": ["countdown", "beep", "compte à rebours", "tic", "tac", "secondes"] },
    { "key": "notify", "section": "alerts", "label": "Notification when done", "default": true,
      "help": "With “Stop” and “+5 min” buttons: handy in fullscreen, when the bar is hidden",
      "words": ["notification", "popup", "alert", "notifier", "plein écran", "fullscreen"] },
    { "key": "respectDnd", "section": "alerts", "label": "Respect Do Not Disturb", "default": true,
      "help": "In Do Not Disturb, no sound: the pill still pulses",
      "words": ["dnd", "silent", "quiet", "mute", "ne pas déranger", "silence", "muet"] }
];

// The battery levels a setting may declare, for the view and the tests
var LEVELS = ["high", "some", "light"];

function _visible(s) {
    return !s.pending;
}

// The settings the view may draw (pending ones are held back)
function visibleSettings() {
    return SETTINGS.filter(_visible);
}

// The sections that have at least one visible setting, in table order
function visibleSections() {
    const used = {};
    for (const s of visibleSettings())
        used[s.section] = true;
    return SECTIONS.filter(x => used[x.id]);
}

// The settings of one section, in table order
function settingsOf(sectionId) {
    return visibleSettings().filter(s => s.section === sectionId);
}

// The section id a setting key is filed under, "" when unknown
function sectionOf(key) {
    const s = SETTINGS.find(x => x.key === key);
    return s ? s.section : "";
}

// The next / previous visible section for the keyboard. Stops at the ends
// (no wrap); an unknown id starts from the first section.
function neighbour(sectionId, step) {
    const ids = visibleSections().map(x => x.id);
    if (ids.length === 0)
        return "";
    const at = ids.indexOf(sectionId);
    if (at < 0)
        return ids[0];
    return ids[Math.min(ids.length - 1, Math.max(0, at + step))];
}

function nextSection(sectionId) {
    return neighbour(sectionId, 1);
}

function previousSection(sectionId) {
    return neighbour(sectionId, -1);
}

// The visible costly settings of one battery level ("high" | "some" | "light")
function costly(level) {
    return visibleSettings().filter(s => s.level === level);
}
