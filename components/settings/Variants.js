.pragma library

// The three look choices of Sands (journal, favourites, notice) as
// data: keys, allowed values, defaults and English labels. This is the only
// place that names them; views, settings rows and IPC import it. Pure, no
// state, no side effect. Tested by tests/variants.test.js.

// Longest raw value looked at: anything longer is damaged, not a choice
var MAX_LENGTH = 16;

// Choices of each key in display order: the default is always first
var VARIANTS = {
    "journal": [
        { "value": "strata", "label": "Strata" },
        { "value": "threads", "label": "Threads" }
    ],
    "favourites": [
        { "value": "glasses", "label": "Three glasses" },
        { "value": "rows", "label": "Rows" }
    ],
    "notice": [
        { "value": "pill", "label": "Pill whisper" },
        { "value": "card", "label": "Quiet card" }
    ]
};

// The default value of `key`, or "" for an unknown key
function defaultOf(key) {
    return VARIANTS.hasOwnProperty(key) ? VARIANTS[key][0].value : "";
}

// `raw` when it is an allowed value of `key`, else the default. Anything
// unknown, missing, not a string or too long gives the default.
function clean(key, raw) {
    if (!VARIANTS.hasOwnProperty(key))
        return "";
    if (typeof raw !== "string" || raw.length > MAX_LENGTH)
        return defaultOf(key);
    return VARIANTS[key].some(c => c.value === raw) ? raw : defaultOf(key);
}
