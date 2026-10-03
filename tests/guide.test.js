// Guide.js tests — run with: gjs tests/guide.test.js (from the plugin root)
// Every note must say what happened, what to do, and point to a section
// that really exists in docs/GUIDE.md (value 10).
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/guide.test.js", GLib.get_current_dir())));
const read = path => new TextDecoder().decode(GLib.file_get_contents(dir + "/" + path)[1]);
const G = new Function(read("Guide.js").replace(".pragma library", "") + "; return { rangeNote, fullNote, partialNote, silentNote, previewNote, toastText };")();

let failures = 0, count = 0;

function eq(got, expected, what) {
    count++;
    if (JSON.stringify(got) !== JSON.stringify(expected)) {
        failures++;
        print("✗ " + what + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(got));
    }
}

// GitHub's anchor for a heading: lower case, spaces to dashes, punctuation dropped
const anchors = read("docs/GUIDE.md").split("\n")
    .filter(l => /^#{2,4} /.test(l))
    .map(l => l.replace(/^#+ /, "").toLowerCase().replace(/[^a-z0-9 -]/g, "").replace(/ /g, "-"));

const notes = {
    range: G.rangeNote(),
    full: G.fullNote(50),
    partial: G.partialNote(2, 4, 50),
    silent: G.silentNote(),
    preview: G.previewNote()
};
for (const [name, n] of Object.entries(notes)) {
    eq(typeof n.title === "string" && n.title.length > 0 && n.title.length <= 40, true, name + " has a short title");
    eq(typeof n.hint === "string" && n.hint.length > 0 && n.hint.length <= 60, true, name + " has a short hint");
    eq(anchors.includes(n.anchor), true, name + " points to a real guide section (#" + n.anchor + ")");
}

eq(notes.partial.title, "Started 2 of 4", "a partial start says how many started");
eq(notes.full.hint.includes("50"), true, "the limit is named");
eq(G.toastText(notes.silent), "Sands: The alarm made no sound. Pick another sound in the settings", "toast joins title and hint");

print(failures === 0 ? count + " tests passed" : failures + " of " + count + " tests failed");
if (failures)
    imports.system.exit(1);
