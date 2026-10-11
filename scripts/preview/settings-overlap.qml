import QtQuick
import "mock"
import "mock/Presets.js" as Presets

// Offscreen overlap check of the whole settings page at the narrowest real widths.
// Fails (exit code 1) when two texts or controls intersect, a text is elided or
// wider than its box, or anything leaves the page. Usage:
//   TZ=UTC QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml-qt6 -I imports settings-overlap.qml
Item {
    id: root

    // Widths in px, from the DMS settings panel at its 500 px minimum window:
    //   PluginsTab.qml:84     content = min(550, window - 2 x spacingL)   -> 468
    //   PluginsTab.qml:494    plugin card margins, 2 x spacingL           -> 436
    //   PluginListItem.qml:402 settings Loader margins, 2 x spacingL       -> 404
    // The side navigation of SettingsModal also takes room from the window, so 404 is an
    // upper bound of the real page. The section rail of the approved mockups (NAK-502)
    // is 176 px: 404 - 176 = 228, the narrowest case. 360 is the mockups' own narrow form.
    readonly property var widths: [228, 360, 404]

    // Made-up stores: see mock/Presets.js
    readonly property var presets: Presets.list

    property var failures: []

    function fail(msg) {
        failures.push(msg);
        console.warn("FAIL " + msg);
    }

    // Every visible leaf: a text with something to show, or a control
    function collect(item, out) {
        for (const child of item.children) {
            if (!child.visible)
                continue;
            if (child.objectName === "control" || (child.text !== undefined && child.contentWidth !== undefined && child.text !== ""))
                out.push(child);
            else
                collect(child, out);
        }
        return out;
    }

    function check(tag, page) {
        const leaves = collect(page, []);
        const boxes = leaves.map(l => {
            const p = l.mapToItem(page, 0, 0);
            return {
                name: l.objectName === "control" ? "control" : '"' + l.text.slice(0, 24) + '"',
                x: p.x,
                y: p.y,
                w: l.width,
                h: l.height,
                item: l
            };
        });
        for (const b of boxes) {
            if (b.item.truncated)
                fail(tag + ": " + b.name + " is elided or truncated");
            if (b.item.contentWidth !== undefined && b.item.contentWidth > b.w + 0.5)
                fail(tag + ": " + b.name + " is wider than its box");
            if (b.x < -0.5 || b.x + b.w > page.width + 0.5)
                fail(tag + ": " + b.name + " leaves the page (" + Math.round(b.x) + " + " + Math.round(b.w) + " > " + page.width + ")");
        }
        for (let i = 0; i < boxes.length; i++)
            for (let j = i + 1; j < boxes.length; j++) {
                const a = boxes[i], b = boxes[j];
                if (a.x < b.x + b.w - 0.5 && b.x < a.x + a.w - 0.5 && a.y < b.y + b.h - 0.5 && b.y < a.y + a.h - 0.5)
                    fail(tag + ": " + a.name + " overlaps " + b.name);
            }
        return boxes.length;
    }

    // A row writes its changed value under its own key, and only then
    function checkSaving(page) {
        const row = (function find(item) {
                for (const c of item.children) {
                    if (c.settingKey === "tick")
                        return c;
                    const hit = find(c);
                    if (hit)
                        return hit;
                }
                return null;
            })(page);
        if (!row || page.store.tick !== undefined)
            fail("the tick row is missing, or wrote its value while loading");
        else {
            row.value = true;
            if (page.store.tick !== true)
                fail("the tick row did not save its new value");
        }
    }

    Column {
        id: cases
        Repeater {
            model: root.widths.length * root.presets.length
            SettingsCase {
                readonly property int w: root.widths[Math.floor(index / root.presets.length)]
                pageWidth: w
                preset: root.presets[index % root.presets.length]
            }
        }
    }

    function findItem(item, name) {
        for (const c of item.children) {
            if (c.objectName === name)
                return c;
            const hit = findItem(c, name);
            if (hit)
                return hit;
        }
        return null;
    }

    // Search wiring: a query finds a setting, picking it opens its section and clears
    // the query, a nonsense query finds nothing
    function checkSearch(page) {
        const sp = findItem(page, "settingsPage");
        sp.query = "sound";
        if (sp.results.length === 0)
            fail("search finds nothing for \"sound\"");
        else {
            const hit = sp.results[0];
            sp.open(hit.section, hit.key);
            if (sp.section !== hit.section || sp.query !== "")
                fail("picking a result did not open its section and clear the query");
        }
        sp.query = "zzqqxxjj";
        if (sp.results.length !== 0)
            fail("a nonsense query found a setting");
        sp.query = "";
    }

    // Every section is opened in turn on every page and measured
    readonly property var sectionIds: ["timers", "appearance", "alerts"]
    property int phase: -1
    property int leaves: 0

    function openPhase() {
        phase++;
        if (phase >= sectionIds.length) {
            checkSearch(cases.children[0].page);
            console.warn(failures.length === 0 ? "OK: no overlap in " + leaves + " texts and controls" : failures.length + " problems");
            Qt.exit(failures.length === 0 ? 0 : 1);
            return;
        }
        for (let i = 0; i < cases.children.length - 1; i++) {
            const c = cases.children[i];
            if (c.page)
                findItem(c.page, "settingsPage").section = sectionIds[phase];
        }
        settle.restart();
    }

    // The rows load their saved value through Qt.callLater, so wait until the pages
    // have laid out again before measuring.
    Timer {
        id: settle
        interval: 300
        onTriggered: {
            for (let i = 0; i < cases.children.length - 1; i++) {
                const c = cases.children[i];
                if (c.page)
                    root.leaves += root.check(root.sectionIds[root.phase] + " " + c.page.width + " px, case " + (i % root.presets.length), c.page);
            }
            if (root.sectionIds[root.phase] === "alerts")
                root.checkSaving(cases.children[0].page);
            root.openPhase();
        }
    }

    Component.onCompleted: openPhase()
}
