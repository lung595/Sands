.pragma library

// Known durations: a short built-in table (English and French, D89) plus the
// user's own entries. Pure: no QML, no clock, no side effects. Durations are
// in seconds.

var MAX_ENTRIES = 50;
var MAX_NAME = 40;
var MIN_SECONDS = 5;
var MAX_SECONDS = 24 * 3600;
var MAX_QUERY = 80;

// [seconds, names...]; every name is looked up through key(), so accents
// and case do not matter here either.
var BUILT_IN = [
    [180, "green tea", "thé vert", "the vert"],
    [240, "black tea", "thé noir", "the noir"],
    [300, "tea", "thé", "the", "herbal tea", "tisane", "infusion"],
    [240, "french press", "cafetière à piston", "cafetiere a piston"],
    [360, "soft-boiled egg", "soft boiled egg", "œuf à la coque", "oeuf a la coque"],
    [420, "medium egg", "œuf mollet", "oeuf mollet"],
    [600, "hard-boiled egg", "hard boiled egg", "œuf dur", "oeuf dur"],
    [600, "pasta", "pâtes", "pates"],
    [720, "rice", "riz"],
    [1200, "brown rice", "riz complet"],
    [900, "quinoa"],
    [1200, "power nap", "sieste"],
    [2400, "pizza"]
];

// Lowercase, no accents, ligatures spelled out, punctuation folded to single
// spaces, so "Thé-vert" and "the  vert" are the same key.
function key(text) {
    if (typeof text !== "string")
        return "";
    var s = text.slice(0, MAX_QUERY).toLowerCase().replace(/œ/g, "oe").replace(/æ/g, "ae");
    if (s.normalize)
        s = s.normalize("NFD").replace(/[̀-ͯ]/g, "");
    return s.replace(/[^a-z0-9]+/g, " ").trim();
}

// The valid, capped entries of `raw` ([{name, seconds}, …]) as a map
// key → seconds. Malformed ones are skipped; for a repeated name the last wins.
function userMap(raw) {
    var map = {};
    if (!Array.isArray(raw))
        return map;
    var n = Math.min(raw.length, MAX_ENTRIES);
    for (var i = 0; i < n; i++) {
        var e = raw[i];
        if (!e || typeof e.name !== "string" || typeof e.seconds !== "number")
            continue;
        var k = key(e.name);
        if (k === "" || e.name.length > MAX_NAME || !isFinite(e.seconds))
            continue;
        if (e.seconds < MIN_SECONDS || e.seconds > MAX_SECONDS)
            continue;
        map[k] = Math.round(e.seconds);
    }
    return map;
}

// Seconds for `name`: the user's entry first, then the built-in table, else null.
function lookup(name, userEntries) {
    var k = key(name);
    if (k === "")
        return null;
    var user = userMap(userEntries);
    if (Object.prototype.hasOwnProperty.call(user, k))
        return user[k];
    for (var i = 0; i < BUILT_IN.length; i++)
        for (var j = 1; j < BUILT_IN[i].length; j++)
            if (key(BUILT_IN[i][j]) === k)
                return BUILT_IN[i][0];
    return null;
}
