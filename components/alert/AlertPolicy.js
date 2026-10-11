.pragma library

// Pure rules for the visual alert of a finished timer: which one to draw and
// when. No QML, no side effects. The settings page, the host and the IPC all
// ask here, so the rule exists once.

const KINDS = ["dune", "halo", "none"];
const WHEN = ["muted", "always"];
const DEFAULT_KIND = "dune";
const DEFAULT_WHEN = "muted";

// The "sound" setting value that means no sound. Both choices are kept when
// the alert is also "none"; the page only warns (isSilent).
const SILENT_SOUND = "none";

// Saved values come from a file the user can edit: anything unknown falls
// back to the default instead of failing.
function kindOf(raw) {
    return KINDS.indexOf(raw) >= 0 ? raw : DEFAULT_KIND;
}

function whenOf(raw) {
    return WHEN.indexOf(raw) >= 0 ? raw : DEFAULT_WHEN;
}

// soundState: { choice, volume (0..1), outputMuted, hasOutput }. The alarm
// cannot be heard when the sound is on its silent choice, its volume is 0,
// the output is muted or there is no output at all. A missing field counts
// as audible: a visual alert nobody asked for is worse than a missed one
// only when the state is known.
function isInaudible(soundState) {
    const s = soundState || {};
    return s.choice === SILENT_SOUND
        || (typeof s.volume === "number" && s.volume <= 0)
        || s.outputMuted === true
        || s.hasOutput === false;
}

// Whether to draw the alert now. Full screen hides it (D482) unless the user
// allowed it; that switch covers the halo too (Q177).
function shouldShow(kind, when, soundState, fullscreen, showOverFullscreen) {
    if (kindOf(kind) === "none")
        return false;
    if (fullscreen === true && showOverFullscreen !== true)
        return false;
    return whenOf(when) === "always" || isInaudible(soundState);
}

// True when a finished timer would give no sign at all: no sound and no
// visual alert.
function isSilent(soundChoice, kind) {
    return soundChoice === SILENT_SOUND && kindOf(kind) === "none";
}

// Second part of the legend under the alert: why it is shown. Nothing extra
// when it is shown "every time" over an audible sound.
function legendReason(kind, when, soundState) {
    if (kindOf(kind) === "none")
        return "";
    if (soundState && soundState.choice === SILENT_SOUND)
        return "No sound chosen";
    return isInaudible(soundState) ? "Sound is muted" : "";
}
