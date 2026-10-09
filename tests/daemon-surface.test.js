// Daemon surface test — run with: gjs tests/daemon-surface.test.js (from the plugin root)
// Every member the views read from the daemon (`daemon.X`, `daemon?.X`) must
// still be declared by TimerDaemon.qml, so a split cannot silently drop one
// (a missing property reads as undefined, and the view just stops reacting).
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq, done } = imports.harness;
const GLib = imports.gi.GLib;

const dir = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const read = path => new TextDecoder().decode(GLib.file_get_contents(dir + "/" + path)[1]);

const declared = new Set([...read("TimerDaemon.qml").matchAll(/^\s*(?:readonly property|property|signal|function)\s+(?:\w+\s+)?(\w+)/gm)].map(m => m[1]));

// Views: the root QML files and components/, never the preview mocks
const views = ["TimerWidget.qml", "TimerLauncher.qml", "TimerSettings.qml", "components/TimerPanelContent.qml", "components/Hourglass.qml", "components/HelpNote.qml"]
    .filter(f => GLib.file_test(dir + "/" + f, GLib.FileTest.EXISTS));
const used = new Set();
for (const f of views)
    for (const m of read(f).matchAll(/\bdaemon\??\.(\w+)/g))
        used.add(m[1]);

eq(used.size > 0, true, "the views read some daemon members");
for (const name of [...used].sort())
    eq(declared.has(name), true, "TimerDaemon.qml declares '" + name + "', read by a view");
done();
