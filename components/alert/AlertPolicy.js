.pragma library

// Pure rules for the visual alert of a finished timer: which one to draw and
// when. No QML, no side effects. The settings page, the host and the IPC all
// ask here, so the rule exists once.

const KINDS = ["dune", "halo", "none"];
const WHEN = ["muted", "always"];
const DEFAULT_KIND = "dune";
const DEFAULT_WHEN = "always";

// Where the alert is drawn ("alertScreen"): on every screen, on the screen
// that has the focus at the ring point, or on one screen by its output name
// (for example "DP-2"). Anything else saved is read as an output name.
const SCREEN_ALL = "all";
const SCREEN_FOCUSED = "focused";
const DEFAULT_SCREEN = SCREEN_ALL;

// The "sound" setting value that means no sound. Reserved: Sound.js does not
// offer it yet (soundFile("none") would still ring the default), so the story
// that wires the host into the daemon adds it there and imports this constant
// from one place instead of keeping a copy (Q181). Both choices are kept when the alert is
// also "none"; the page only warns (isSilent).
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

function screenOf(raw) {
    return typeof raw === "string" && raw !== "" ? raw : DEFAULT_SCREEN;
}

// Names of the screens the alert is drawn on. setting: the saved choice;
// names: the outputs plugged in now; focused: the output that has the focus
// ("" when the compositor does not say). A screen that is not there (unplugged,
// renamed, focus unknown) gives every screen: the alert is never drawn on none
// while a screen exists.
function screensFor(setting, names, focused) {
    const all = (names || []).filter(n => typeof n === "string" && n !== "");
    const choice = screenOf(setting);
    if (choice === SCREEN_ALL)
        return all;
    const wanted = choice === SCREEN_FOCUSED ? focused : choice;
    return all.indexOf(wanted) >= 0 ? [wanted] : all;
}

// The screens (objects with a name) kept for a list of names taken at the
// ring point. A list that matches no screen any more keeps them all.
function pickScreens(screens, names) {
    const list = screens || [];
    const kept = [];
    for (let i = 0; i < list.length; i++)
        if (list[i] && (names || []).indexOf(list[i].name) >= 0)
            kept.push(list[i]);
    return kept.length > 0 ? kept : list;
}

// Rows of the "Show on" list: every screen, the active one, then one per
// screen plugged in, "Model (DP-2)" or the bare name without a model. A saved
// screen that is unplugged stays in the list, marked, so the row shows what
// is saved.
function screenChoices(screens, saved) {
    const out = [
        { "label": "All screens", "value": SCREEN_ALL },
        { "label": "Active screen", "value": SCREEN_FOCUSED }
    ];
    const list = screens || [];
    for (let i = 0; i < list.length; i++) {
        const s = list[i];
        if (!s || typeof s.name !== "string" || s.name === "" || out.some(o => o.value === s.name))
            continue;
        const model = typeof s.model === "string" ? s.model.trim() : "";
        out.push({ "label": model !== "" && model !== s.name ? model + " (" + s.name + ")" : s.name, "value": s.name });
    }
    const choice = screenOf(saved);
    if (!out.some(o => o.value === choice))
        out.push({ "label": choice + " (not connected)", "value": choice });
    return out;
}

// True when a finished timer would give no sign at all: no sound and no
// visual alert.
function isSilent(soundChoice, kind) {
    return soundChoice === SILENT_SOUND && kindOf(kind) === "none";
}

// Second part of the legend under the alert, as on the approved page: "No
// sound chosen", else "Click to stop" when shown every time, else "Sound is
// muted". Shown every time over a sound that cannot be heard (volume 0, muted
// or no output) keeps "Sound is muted": the page has no text for that case.
function legendReason(kind, when, soundState) {
    if (kindOf(kind) === "none")
        return "";
    if (soundState && soundState.choice === SILENT_SOUND)
        return "No sound chosen";
    if (isInaudible(soundState))
        return "Sound is muted";
    return whenOf(when) === "always" ? "Click to stop" : "";
}

// Several timers ending together share one alert named after the last one to
// ring (the latest finishedAt); null when none rings.
function lastRinging(timers) {
    let last = null;
    for (const t of timers || [])
        if (t.state === "ringing" && (last === null || t.finishedAt >= last.finishedAt))
            last = t;
    return last;
}
