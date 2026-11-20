// Strings.js tests — run with: gjs tests/strings.test.js (from the plugin root)
// Every language has the keys of English, the same %n placeholders, no
// emoji; tr() fills templates and falls back to English; langOf reads a
// locale name the way DMS does; every key the modules ask for exists.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done, dir, read } = imports.harness;
const GLib = imports.gi.GLib;
const S = load("Strings.js");

const langs = Object.keys(S.TABLE);
eq(langs, ["en", "fr"], "the languages");
const en = S.TABLE.en;
const placeholders = text => [...new Set(text.match(/%\d/g) || [])].sort();

// Parity: same keys both ways, same placeholders, non-empty strings
for (const lang of langs) {
    const t = S.TABLE[lang];
    eq(Object.keys(en).filter(k => !(k in t)), [], lang + " has every English key");
    eq(Object.keys(t).filter(k => !(k in en)), [], lang + " has no key English lacks");
    for (const k of Object.keys(t)) {
        eq(typeof t[k] === "string" && t[k].trim().length > 0, true, lang + " " + k + " is a non-empty string");
        if (k in en)
            eq(placeholders(t[k]), placeholders(en[k]), lang + " " + k + " has the placeholders of English");
    }
}

// No emoji anywhere (Material Symbols icons only, never emoji)
const emoji = /\p{Extended_Pictographic}|️|‍/u;
for (const lang of langs)
    eq(Object.keys(S.TABLE[lang]).filter(k => emoji.test(S.TABLE[lang][k])), [], lang + ": no emoji");
// The check itself sees one
eq(emoji.test("Pasta ⏰"), true, "the emoji check finds an emoji");
eq(emoji.test("%1 → %4 · × — −"), false, "arrows, dots and dashes are not emoji");

// langOf: the language of a locale name, as DMS reads it
eq(S.langOf("fr"), "fr", "fr");
eq(S.langOf("fr_FR"), "fr", "fr_FR");
eq(S.langOf("fr-CA"), "fr", "fr-CA");
eq(S.langOf("FR_be"), "fr", "case does not matter");
eq(S.langOf("fr_FR.UTF-8"), "fr", "an encoding suffix");
eq(S.langOf("en_GB"), "en", "en_GB");
for (const other of ["de_DE", "C", "", "frx", null, undefined, 42])
    eq(S.langOf(other), "en", "English for " + JSON.stringify(other));

// tr: templates, languages, fallbacks
eq(S.tr("name.timer"), "Timer", "no language: English");
eq(S.tr("name.timer", "fr_FR"), "Minuteur", "French by locale name");
eq(S.tr("guide.partialTitle", "en", 2, 4), "Started 2 of 4", "two placeholders");
eq(S.tr("guide.partialTitle", "fr", 2, 4), "2 sur 4 démarrés", "two placeholders, French order");
eq(S.tr("command.rename", "en", "Tea", "", "", "Infusion"), "Tea → Infusion", "a placeholder far down");
eq(S.tr("guide.fullHint", "en"), "At most %1 timers at once: cancel one first", "a missing value keeps its placeholder");
eq(S.tr("guide.fullHint", "en", 0), "At most 0 timers at once: cancel one first", "0 is a value");
eq(S.tr("no.such.key", "fr"), "no.such.key", "an unknown key shows itself");
eq(S.has("name.timer"), true, "has a key");
eq(S.has("no.such.key"), false, "has not");
eq(S.fill("%2 %1 %3", ["a", "b"]), "b a %3", "fill");
eq(S.fill("%1", ["$&"]), "$&", "a value is taken as is");
// A key missing from one language falls back to English
S.TABLE.en["test.only"] = "Only %1";
eq(S.tr("test.only", "fr", "x"), "Only x", "a key French lacks: English");
delete S.TABLE.en["test.only"];

// Every key asked for in the sources exists: Strings.tr("key", …) and the
// "command." keys Commands.js builds
const sources = sub => {
    const d = GLib.Dir.open(dir + "/" + sub, 0);
    const found = [];
    let name;
    while ((name = d.read_name()) !== null) {
        const path = (sub === "." ? "" : sub + "/") + name;
        if (/^(out|tests|scripts|\.git|node_modules)$/.test(name) && sub === ".")
            continue;
        if (GLib.file_test(dir + "/" + path, GLib.FileTest.IS_DIR))
            found.push(...sources(path));
        else if (/\.(qml|js)$/.test(name))
            found.push(path);
    }
    return found;
};
const files = sources(".");
eq(files.includes("components/daemon/IpcReplies.js"), true, "the scan finds the sources");
const asked = new Set();
for (const f of files) {
    const src = read(f);
    for (const m of src.matchAll(/Strings\.tr\(\s*"([\w.]+)"\s*[,)]/g))
        asked.add(m[1]);
    for (const m of src.matchAll(/Strings\.tr\([^;\n]*?\?\s*"([\w.]+)"\s*:\s*"([\w.]+)"/g)) {
        asked.add(m[1]);
        asked.add(m[2]);
    }
    if (f === "Commands.js")
        for (const m of src.matchAll(/\btr\("(\w+)"/g))
            asked.add("command." + m[1]);
}
eq(asked.size > 30, true, "the scan finds the keys asked for");
eq(["name.timer", "name.alarm", "command.adjust", "known.usual"].every(k => asked.has(k)), true, "the scan reads every form of call");
eq([...asked].filter(k => !S.has(k)), [], "every key asked for exists");

done();
