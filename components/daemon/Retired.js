.pragma library

// Settings keys an older Sands saved and this one no longer reads. They are
// dropped once when the daemon starts; the behaviour is then the default
// one. Pure, no side effect. Tested by tests/retired.test.js.

// endMode: the old end-of-timer mode (a timer now always ends with sound,
// visual alert and notification, as the switches say). timerEndMode: the
// same choice under its other name. Both go without a word.
// personalActions, actionWords: the end actions (own commands and launcher
// words, gone in 1.7.0). They go too, and whoever had some is told once.
var END_ACTION_KEYS = ["personalActions", "actionWords"];
var KEYS = ["endMode", "timerEndMode"].concat(END_ACTION_KEYS);
// What a timer of an older Sands may carry for its end action
var TIMER_FIELDS = ["actionId"];
// Plugin state flag: the removal of the end actions was dealt with, told or not
var NOTICE_KEY = "endActionsRetired";

function _plain(v) {
    return !!v && typeof v === "object" && !Array.isArray(v);
}

// Something was saved there: a non-empty list or object
function _some(v) {
    return Array.isArray(v) ? v.length > 0 : _plain(v) && Object.keys(v).length > 0;
}

// { settings, removed, hadEndActions }: a copy of `settings` (one plugin's
// saved settings) without the retired keys, the keys that were there, and
// whether the user had end actions of their own (commands or changed words).
// `settings` itself is never changed; anything that is not a plain object
// gives { {}, [], false }.
function sweep(settings) {
    if (!_plain(settings))
        return { "settings": {}, "removed": [], "hadEndActions": false };
    const kept = {};
    const removed = [];
    Object.keys(settings).forEach(k => {
        if (KEYS.indexOf(k) >= 0)
            removed.push(k);
        else
            kept[k] = settings[k];
    });
    return {
        "settings": kept,
        "removed": removed,
        "hadEndActions": END_ACTION_KEYS.some(k => _some(settings[k]))
    };
}

// The toast is shown once ever, and only to whoever had end actions
function notice(hadEndActions, alreadyDone) {
    return hadEndActions === true && alreadyDone !== true;
}

function toastText(localeName) {
    return /^fr/i.test(localeName || "") ? "Actions de fin retirées" : "End actions removed";
}

// The saved timers without their end action: a timer that had one ends as
// any other. Changed timers are copies; anything but a list comes back as is.
function stripTimers(list) {
    if (!Array.isArray(list))
        return list;
    return list.map(t => {
        if (!_plain(t) || !TIMER_FIELDS.some(f => f in t))
            return t;
        const copy = Object.assign({}, t);
        TIMER_FIELDS.forEach(f => delete copy[f]);
        return copy;
    });
}
