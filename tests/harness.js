// Shared by the daemon tests: loads a pure .js module of the plugin the way
// QML does (without `.pragma library`), resolves its `.import "x.js" as X`
// lines to the modules it names, and counts the checks.
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const read = path => new TextDecoder().decode(GLib.file_get_contents(dir + "/" + path)[1]);

// The module at `path` (relative to the plugin root) as an object of all
// its top-level functions and vars
function load(path) {
    const imported = [];
    const src = read(path).replace(".pragma library", "").replace(/^\.import "([^"]+)" as (\w+)$/gm, (_, rel, name) => {
        imported.push([name, load(GLib.path_get_dirname(path) === "." ? rel.replace(/^\.\.\/\.\.\//, "") : GLib.canonicalize_filename(rel, dir + "/" + GLib.path_get_dirname(path)).slice(dir.length + 1))]);
        return "";
    });
    const names = [...src.matchAll(/^(?:function|var|const) (\w+)/gm)].map(m => m[1]);
    return new Function(...imported.map(i => i[0]), src + "; return { " + names.join(", ") + " };")(...imported.map(i => i[1]));
}

let failures = 0, count = 0;

function eq(got, expected, what) {
    count++;
    if (JSON.stringify(got) !== JSON.stringify(expected)) {
        failures++;
        print("✗ " + what + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(got));
    }
}

// Prints the summary and sets the exit code
function done() {
    print(failures === 0 ? "✓ " + count + " tests passed" : "\n" + failures + " / " + count + " failed");
    imports.system.exit(failures === 0 ? 0 : 1);
}
