import QtQuick
import "mock"
import "mock/Presets.js" as Presets
import "../../components/settings/Sections.js" as Sections
import qs.Common

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

    // Esc clears a query and is left alone otherwise (focus keys: tests/qml-page)
    function checkKeys(page) {
        const sp = findItem(page, "settingsPage");
        sp.query = "sound";
        if (!sp.clearQuery() || sp.query !== "")
            fail("Esc does not clear a query");
        if (sp.clearQuery())
            fail("Esc is swallowed with nothing to clear");
        sp.section = "timers";
        sp.query = "sound";
        sp.openFirst();
        if (sp.query !== "" || sp.section !== "alerts")
            fail("Enter does not open the first result");
    }

    // After a pick, the highlight sits on the row (or on its anchor when hidden)
    property var flashKeys: []
    function nextFlash() {
        if (flashKeys.length === 0) {
            console.warn(failures.length === 0 ? "OK: no overlap in " + leaves + " texts and controls" : failures.length + " problems");
            Qt.exit(failures.length === 0 ? 0 : 1);
            return;
        }
        const sp = findItem(cases.children[0].page, "settingsPage");
        const key = flashKeys[0];
        sp.open(Sections.sectionOf(key), key);
        flashCheck.restart();
    }

    Timer {
        id: flashCheck
        interval: 150
        onTriggered: {
            const sp = root.findItem(cases.children[0].page, "settingsPage");
            const key = root.flashKeys.shift();
            const row = sp.flashTarget(key);
            const flash = root.findItem(sp, "flash");
            if (!row)
                root.fail("no row to highlight for " + key);
            else {
                const p = row.mapToItem(flash.parent, 0, 0);
                if (flash.height <= 0 || Math.abs(flash.x - p.x) > 0.5 || Math.abs(flash.y - p.y) > 0.5 || Math.abs(flash.width - row.width) > 0.5 || Math.abs(flash.height - row.height) > 0.5)
                    root.fail("the highlight is not on the row of " + key);
            }
            if (sp.fadeDuration !== (Qt.application.arguments.indexOf("reduce") >= 0 ? 150 : 600))
                root.fail("the fade duration ignores Reduce motion");
            root.nextFlash();
        }
    }

    function findReportRow(item) {
        for (const c of item.children) {
            if (c.settingKey === "report")
                return c;
            const hit = findReportRow(c);
            if (hit)
                return hit;
        }
        return null;
    }

    // The "Copy report" row in its other states, on every page: copied, the
    // guided message, and the label of the GitHub mark (focus puts it up)
    readonly property var reportStatesList: ["copied", "none", "label"]
    property int reportStep: 0

    Timer {
        id: reportStates
        interval: 400
        onTriggered: {
            const state = root.reportStatesList[root.reportStep];
            for (let i = 0; i < cases.children.length - 1; i++) {
                const c = cases.children[i];
                if (!c.page)
                    continue;
                const row = root.findReportRow(c.page);
                if (!row)
                    continue;
                if (root.reportStep > 0) {
                    // Measure what the previous step set up
                    const tag = "help/" + root.reportStatesList[root.reportStep - 1] + " " + c.page.width + " px, case " + (i % root.presets.length);
                    root.leaves += root.check(tag, c.page);
                }
                if (state === undefined)
                    continue;
                row.daemon.reportClipboard.result = state === "label" ? "idle" : state;
                if (state === "label")
                    row.markControl.forceActiveFocus();
            }
            root.reportStep++;
            if (root.reportStep <= root.reportStatesList.length)
                restart();
            else
                root.openPhase();
        }
    }

    // Every section is opened in turn on every page and measured
    // "timers" comes twice: the second time with a refusal shown under every row and a
    // command being typed, the tallest the section gets
    readonly property var sectionIds: ["timers", "timers", "appearance", "alerts", "advanced", "help"]
    property int phase: -1
    property int leaves: 0

    function openPhase() {
        phase++;
        if (phase >= sectionIds.length) {
            checkSearch(cases.children[0].page);
            checkKeys(cases.children[0].page);
            flashKeys = Sections.visibleSettings().map(s => s.key);
            nextFlash();
            return;
        }
        for (let i = 0; i < cases.children.length - 1; i++) {
            const c = cases.children[i];
            if (c.page)
                findItem(c.page, "settingsPage").section = sectionIds[phase];
        }
        if (phase === 1)
            Qt.callLater(stressEndActions);
        settle.restart();
    }

    // Every end-action row shows a long refusal, and the new-command form is open with one
    function stressEndActions() {
        const long = "“abcdefghijklmnopqrstuvwx” already belongs to Stop the music. Pick another word for this action.";
        for (let i = 0; i < cases.children.length - 1; i++) {
            const c = cases.children[i];
            const section = c.page ? findRow(c.page, "endActions") : null;
            if (!section)
                continue;
            for (const r of section.rows)
                section.setError(r.id, {
                    "word": long
                });
            section.drafting = true;
            section.draftError = long;
            section.draftField = "command";
        }
    }

    function findRow(item, key) {
        for (const c of item.children) {
            if (c.settingKey === key)
                return c;
            const hit = findRow(c, key);
            if (hit)
                return hit;
        }
        return null;
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
            if (root.sectionIds[root.phase] === "help") {
                root.reportStep = 0;
                reportStates.restart();
                return;
            }
            root.openPhase();
        }
    }

    Component.onCompleted: openPhase()
}
