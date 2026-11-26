// Tooltips hide again — run with: gjs tests/tooltips.test.js (from the plugin root)
// A DankTooltipV2 stays up until hide() is called: every QML file that shows
// one must hide it as often as it shows it (pointer left, item gone).
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { read, eq, done, listFiles } = imports.harness;

const files = listFiles("components", p => p.endsWith(".qml"), () => false).filter(f => read(f).includes("DankTooltipV2"));
eq(files.length >= 4, true, "the tooltip files are found");
for (const f of files) {
    const src = read(f);
    const count = re => (src.match(re) || []).length;
    eq(count(/\w+\.hide\(\)/g), count(/\w+\.show\(/g), "every shown tooltip hides in " + f);
}

done();
