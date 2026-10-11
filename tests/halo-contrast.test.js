// Contrast of the halo legend (surfaceText on surfaceContainerHigh, as drawn by HaloRim.qml)
// on every stock DMS theme, light and dark. Skipped when DMS is not installed.
// Run with: gjs tests/halo-contrast.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq, done } = imports.harness;
const GLib = imports.gi.GLib;

const path = "/usr/share/quickshell/dms/Common/StockThemes.js";
if (!GLib.file_test(path, GLib.FileTest.EXISTS)) {
    print("skipped: DMS stock themes not found");
} else {
    const src = new TextDecoder().decode(GLib.file_get_contents(path)[1]);
    const themes = new Function(src + "; return StockThemes;")();

    // WCAG relative luminance
    const lum = hex => {
        const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
            .map(c => c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };
    const ratio = (a, b) => {
        const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x);
        return (hi + 0.05) / (lo + 0.05);
    };

    let min = Infinity;
    for (const mode of ["DARK", "LIGHT"])
        for (const [id, t] of Object.entries(themes[mode])) {
            const r = ratio(t.surfaceText, t.surfaceContainerHigh);
            min = Math.min(min, r);
            eq(r >= 4.5, true, "legend contrast " + mode + " " + id + " " + r.toFixed(1));
        }
    print("lowest legend contrast: " + min.toFixed(1) + ":1");
}
done();
