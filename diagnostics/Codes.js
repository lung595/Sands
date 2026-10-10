.pragma library

// What THIS plugin may say. It is the only diagnostics file that differs from
// one plugin to the next; the others are copied as they are. Every code is
// explained in docs/DEBUGGING.md (a test fails when one is missing there).
//
// A code is PREFIX-<level><number>: E error, W warning, I info, D debug.
// Errors and warnings also go to the DMS journal (console.error/warn, the only
// calls DMS keeps); info and debug stay in the memory buffer.

var LABEL = "sands";
var PLUGIN = "Sands";

// Every key an event may carry, with the only values it may hold ("int",
// "bool", or a list of words). No key takes free text: a timer label, a launcher
// query or a sound path can never be a value.
var FIELDS = {
    "action": ["start", "pause", "resume", "stop", "add", "clear", "snooze", "dismiss"],
    "reason": ["bad_input", "not_found", "limit", "no_sound", "refused", "bad_data", "killed", "unknown"],
    "tool": ["pw_play", "notify_send", "dms"],
    "state": ["running", "paused", "ringing", "idle", "hidden", "visible"],
    "surface": ["widget", "daemon", "launcher", "settings", "panel"],
    "via": ["button", "ipc", "script"],
    "code": "int",
    "count": "int",
    "ms": "int"
};

var CODES = {
    "SND-E001": { "text": "A timer action failed", "fields": ["action", "reason"] },
    "SND-E002": { "text": "The saved timers could not be read", "fields": ["reason"] },
    "SND-E003": { "text": "A helper program stopped unexpectedly", "fields": ["tool", "code"] },
    "SND-E004": { "text": "The ring sound could not be played", "fields": ["reason"] },
    "SND-W010": { "text": "A helper program is missing", "fields": ["tool"] },
    "SND-W011": { "text": "A timer text was not understood", "fields": ["reason"] },
    "SND-I020": { "text": "A surface was loaded", "fields": ["surface"] },
    "SND-I021": { "text": "A surface was unloaded", "fields": ["surface"] },
    "SND-I030": { "text": "A diagnostic report was requested", "fields": ["via"] },
    "SND-D040": { "text": "A timer changed state", "fields": ["state", "count"] }
};

// The surfaces a report may list as active
var SURFACES = ["widget", "daemon", "launcher", "settings", "panel"];

// The settings a report may show: the ones that choose a behaviour. The custom
// sound path and the launcher trigger word can hold the user's own text and are
// left out; a sound that is a file path shows as "?".
var SETTINGS = {
    "hourglassStyle": ["classic", "glassOfTime"],
    "sound": ["default", "silt-chime", "custom"],
    "volume": "int",
    "ringDuration": "int",
    "notify": "bool",
    "rampUp": "bool",
    "tick": "bool",
    "respectDnd": "bool",
    "noTrigger": "bool"
};

// What the plugin reports about itself at the moment of the report (counts of
// what is alive), never about its surroundings
var FACTS = {
    "timers": "int",
    "timersRunning": "int",
    "timersRinging": "int",
    "processesRunning": "int",
    "reduceMotion": "bool"
};
