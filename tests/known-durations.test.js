// Known durations test — run with: gjs tests/known-durations.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq, done, load } = imports.harness;
const K = load("KnownDurations.js");

// Built-in table, both languages
eq(K.lookup("green tea"), 180, "en green tea");
eq(K.lookup("thé vert"), 180, "fr thé vert");
eq(K.lookup("soft-boiled egg"), 360, "en soft-boiled egg");
eq(K.lookup("œuf à la coque"), 360, "fr oeuf à la coque");
eq(K.lookup("rice"), 720, "en rice");
eq(K.lookup("riz"), 720, "fr riz");

// Case, accents, punctuation
eq(K.lookup("GREEN  Tea"), 180, "case and spaces");
eq(K.lookup("THE VERT"), 180, "accents ignored");
eq(K.lookup("soft boiled egg"), 360, "hyphen folded");

// Unknown or bad input
eq(K.lookup("unicorn"), null, "unknown");
eq(K.lookup(""), null, "empty");
eq(K.lookup(null), null, "null");
eq(K.lookup(42), null, "number");
eq(K.lookup("x".repeat(5000)), null, "huge query");

// User entries: new name, override, accents
eq(K.lookup("Ramen", [{ name: "ramen", seconds: 210 }]), 210, "user entry");
eq(K.lookup("green tea", [{ name: "Green Tea", seconds: 150 }]), 150, "user wins");
eq(K.lookup("thé vert", [{ name: "the vert", seconds: 150 }]), 150, "user override accent-insensitive");
eq(K.lookup("green tea", [{ name: "x", seconds: 9 }]), 180, "other entry leaves built-in");
eq(K.lookup("a", [{ name: "a", seconds: 10 }, { name: "a", seconds: 20 }]), 20, "last duplicate wins");

// Caps
eq(K.lookup("long", [{ name: "x".repeat(41), seconds: 60 }]), null, "name too long");
eq(K.lookup("tiny", [{ name: "tiny", seconds: 4 }]), null, "duration too short");
eq(K.lookup("huge", [{ name: "huge", seconds: 86401 }]), null, "duration too long");
eq(K.lookup("edge", [{ name: "edge", seconds: 86400 }]), 86400, "max duration ok");
const many = [];
for (let i = 0; i < 60; i++) many.push({ name: "item" + String.fromCharCode(97 + (i % 26)) + Math.floor(i / 26), seconds: 60 });
eq(K.lookup("itema0", many), 60, "within count cap");
const over = [];
for (let i = 0; i < 50; i++) over.push({ name: "pad" + i, seconds: 60 });
over.push({ name: "late", seconds: 60 });
eq(K.lookup("late", over), null, "entry beyond count cap ignored");

// Malformed entries never throw
for (const bad of [null, undefined, "str", 5, {}, [null], [undefined], [{}], [{ name: 1, seconds: 60 }], [{ name: "n", seconds: "60" }], [{ name: "n", seconds: NaN }], [{ name: "n", seconds: Infinity }], [{ name: "  ", seconds: 60 }]])
    eq(K.lookup("green tea", bad), 180, "malformed " + JSON.stringify(bad));
done();
