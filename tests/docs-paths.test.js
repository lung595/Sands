// Install path in the docs — run with: gjs tests/docs-paths.test.js (from the plugin root)
// DMS loads plugins from ~/.config/dms/plugins, and the folder must be named
// after the plugin id: ~/.config/dms/plugins/smartTimer. Any other plugin
// install path in the docs or the scripts is a broken install.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { read, eq, done, listFiles } = imports.harness;

const INSTALL = "~/.config/dms/plugins/smartTimer";
const CLONE = "git clone https://github.com/lung595/Sands " + INSTALL;

// Every plugin folder named under a home config path, or under the old
// DankMaterialShell folder, that is not the right one
const HOME = String.raw`(?:~|\$HOME|\$\{HOME\}|/home/[^/\s]+)`;
const PLUGIN_PATH = new RegExp(HOME + String.raw`/\.config/[^\s\x60'"()\[\]<>]*?plugins/[^\s\x60'"()\[\]<>/]*`, "g");
const GOOD = new RegExp("^" + HOME + String.raw`/\.config/dms/plugins/smartTimer$`);
function badPaths(text) {
    const bad = (text.match(PLUGIN_PATH) || []).filter(p => !GOOD.test(p));
    return bad.concat(text.match(/DankMaterialShell\/plugins\b[^\s\x60'"]*/g) || []);
}

// The rule itself
eq(badPaths("git clone x " + INSTALL), [], "the right path passes");
eq(badPaths("cd $HOME/.config/dms/plugins/smartTimer/scripts"), [], "a file inside it passes");
eq(badPaths("~/.config/DankMaterialShell/plugins/Sands"), ["~/.config/DankMaterialShell/plugins/Sands", "DankMaterialShell/plugins/Sands"], "the old folder fails");
eq(badPaths("`~/.config/dms/plugins/Sands`"), ["~/.config/dms/plugins/Sands"], "the display name as folder fails");
eq(badPaths("${HOME}/.config/dms/plugins/smarttimer"), ["${HOME}/.config/dms/plugins/smarttimer"], "the id is case-sensitive");
eq(badPaths("/home/bob/.config/quickshell/dms/plugins/smartTimer"), ["/home/bob/.config/quickshell/dms/plugins/smartTimer"], "another config folder fails");
eq(badPaths("~/.config/niri/config.kdl"), [], "other config files are not install paths");

// Every text file of the docs, the scripts and the tools
const TEXT = /\.(md|sh|py|txt|yml|yaml|html|qml|js|conf|json)$/;
const files = ["README.md", "CONTRIBUTING.md", "CHANGELOG.md", "ROADMAP.md", "docs", "scripts", "tools", ".github"]
    .reduce((acc, f) => listFiles(f, p => TEXT.test(p), (p, n) => ["out", "__pycache__", "node_modules"].includes(n), acc), []);
eq(files.includes("README.md") && files.includes("CONTRIBUTING.md") && files.includes("docs/GUIDE.md"), true, "the docs are read");
for (const f of files)
    eq(badPaths(read(f)), [], "no other plugin install path in " + f);

// The clone command, as written in both places that give it
for (const f of ["README.md", "CONTRIBUTING.md"])
    eq(read(f).includes(CLONE), true, f + " clones into " + INSTALL);

done();
