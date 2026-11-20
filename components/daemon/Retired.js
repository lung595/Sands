.pragma library

// Settings keys an older Sands saved and this one no longer reads. They are
// dropped once, silently, when the daemon starts; the behaviour is then the
// default one. Pure, no side effect. Tested by tests/retired.test.js.

// endMode: the old end-of-timer mode (a timer now always ends with sound,
// visual alert and notification, as the switches say). timerEndMode: the
// same choice under its other name.
var KEYS = ["endMode", "timerEndMode"];

// { settings, removed }: a copy of `settings` (one plugin's saved settings)
// without the retired keys, and the keys that were there. `settings` itself
// is never changed; anything that is not a plain object gives { {}, [] }.
function sweep(settings) {
    if (!settings || typeof settings !== "object" || Array.isArray(settings))
        return { "settings": {}, "removed": [] };
    const kept = {};
    const removed = [];
    Object.keys(settings).forEach(k => {
        if (KEYS.indexOf(k) >= 0)
            removed.push(k);
        else
            kept[k] = settings[k];
    });
    return { "settings": kept, "removed": removed };
}
