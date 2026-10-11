import QtQuick
import qs.Common
import qs.Services
import "../.."
import "../../components/settings"

// Offscreen test of the « When a Sands timer ends » row and of the settings page,
// with a mocked Alex (PluginService.dms). Fails (exit 1) on any overlap at the narrow
// widths, on a control that is not 44 px high, on a label that is not 14 px, on strip
// margins other than 4/8 px, on a wrong chip, and when a change in one page does not
// reach the other, in both directions. Usage:
//   TZ=UTC QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml-qt6 -I imports timer-end-row.qml
Item {
    id: root

    property var failures: []
    // The row alone, at the widths of settings-overlap.qml
    readonly property var widths: [228, 360, 404]

    function fail(msg) {
        failures.push(msg);
        console.warn("FAIL " + msg);
    }

    function find(item, pred) {
        for (const c of item.children) {
            if (pred(c))
                return c;
            const hit = find(c, pred);
            if (hit)
                return hit;
        }
        return null;
    }

    function boxes(row) {
        const out = [];
        (function walk(item) {
                for (const c of item.children) {
                    if (!c.visible)
                        continue;
                    if (c.objectName === "control" || (c.text !== undefined && c.contentWidth !== undefined && c.text !== "")) {
                        const p = c.mapToItem(row, 0, 0);
                        out.push({
                            n: c.text !== undefined ? '"' + c.text.slice(0, 20) + '"' : "control",
                            x: p.x,
                            y: p.y,
                            w: c.width,
                            h: c.height,
                            item: c
                        });
                    } else
                        walk(c);
                }
            })(row);
        return out;
    }

    function check(tag, row) {
        const b = boxes(row);
        for (const a of b) {
            if (a.item.truncated)
                fail(tag + ": " + a.n + " is elided");
            if (a.x < -0.5 || a.x + a.w > row.width + 0.5)
                fail(tag + ": " + a.n + " leaves the row");
        }
        for (let i = 0; i < b.length; i++)
            for (let j = i + 1; j < b.length; j++) {
                const p = b[i], q = b[j];
                if (p.x < q.x + q.w - 0.5 && q.x < p.x + p.w - 0.5 && p.y < q.y + q.h - 0.5 && q.y < p.y + p.h - 0.5)
                    fail(tag + ": " + p.n + " overlaps " + q.n);
            }
    }

    // Counts the chips by their text
    function chipShown(row) {
        // Visible ones only: the section's SwitchRows carry hidden pills of the same text
        const c = find(row, i => i.text === "Light on battery" && i.visible);
        return c !== null && c.parent.visible;
    }

    function rowOf(page) {
        return find(page, c => c.view !== undefined && c.choices !== undefined);
    }

    function lastCall() {
        return JSON.stringify(PluginService.dmsCalls[PluginService.dmsCalls.length - 1]);
    }

    Column {
        id: rows
        Repeater {
            model: root.widths.length * 4
            TimerEndRow {
                required property int index
                readonly property int w: root.widths[Math.floor(index / 4)]
                // 0 absent, 1 react, 2 sands only, 3 alarm in the island
                readonly property int kind: index % 4
                parent: rows
                width: w
                alexLoaded: kind !== 0
                mode: ["", "react", "sands", "alex"][kind]
            }
        }
    }

    property var page: null
    property int step: 0

    // One check per tick, so the mocked `dms` process has answered before each assert
    function next() {
        const row = page ? rowOf(page) : null;
        const segments = row ? find(row, c => c.objectName === "segments") : null;
        switch (step++) {
        case 0:
            matrix();
            PluginService.loadedIds = ["alex"];
            page = Qt.createComponent("../../components/settings/AlertsSection.qml").createObject(root, {
                width: 404,
                soundOptions: [],
                daemon: null
            });
            if (!page)
                fail("page did not load");
            return !!page;
        case 1:
            // Opening the page reads the mode, with the argument array only
            if (lastCall() !== '["ipc","call","alex","timerEndMode"]')
                fail("the page did not read the mode on open: " + lastCall());
            if (page.timerEndMode !== "react")
                fail("the mode read from Alex is " + page.timerEndMode);
            // Sands to Alex: a click on the third choice
            find(segments.children[2], c => c.containsMouse !== undefined).clicked(null);
            return true;
        case 2:
            if (PluginService.dmsCalls.length < 2 || JSON.stringify(PluginService.dmsCalls[PluginService.dmsCalls.length - 2]) !== '["ipc","call","alex","timerEndMode","alex"]')
                fail("the click did not send the expected arguments: " + JSON.stringify(PluginService.dmsCalls));
            if (PluginService.alexMode !== "alex")
                fail("Alex did not take the change");
            if (page.timerEndMode !== "alex" || rowOf(page).view.selected !== "alex")
                fail("the page did not show the change it asked for");
            // Alex to Sands: the notice reaches the open page
            PluginService.setGlobalVar("alex", "timerEndModeChanged", {
                kind: "timerEndModeChanged",
                mode: "sands"
            });
            if (page.timerEndMode !== "sands")
                fail("a notice from Alex did not reach the page");
            PluginService.setGlobalVar("alex", "timerEndModeChanged", {
                kind: "timerEndModeChanged",
                mode: "bogus"
            });
            if (page.timerEndMode !== "sands")
                fail("an invalid notice changed the page");
            // Alex loaded but with no readable answer: greyed, nothing selected
            PluginService.alexMode = "bogus";
            PluginService.pluginUnloaded("alex");
            PluginService.pluginLoaded("alex");
            return true;
        case 3:
            if (!page.alexLoaded || page.timerEndMode !== "" || rowOf(page).view.enabled)
                fail("Alex loaded without an answer: the row is not greyed");
            // Alex removed while Sands runs
            PluginService.loadedIds = [];
            PluginService.pluginUnloaded("alex");
            if (page.alexLoaded || page.timerEndMode !== "" || rowOf(page).view.enabled)
                fail("Alex removed: the row did not grey");
            if (segments.children[0].enabled)
                fail("a greyed segment still takes the mouse and the keyboard");
            return true;
        default:
            return false;
        }
    }

    function checkFades() {
        const r = rows.children[0];
        const was = SettingsData.reduceMotion;
        SettingsData.reduceMotion = false;
        if (r.fadeMs(true) !== 150 || r.fadeMs(false) !== 100)
            fail("fade is " + r.fadeMs(true) + "/" + r.fadeMs(false) + " ms, 150/100 expected");
        SettingsData.reduceMotion = true;
        if (r.fadeMs(true) !== 100 || r.fadeMs(false) !== 100)
            fail("Reduce motion fade is " + r.fadeMs(true) + "/" + r.fadeMs(false) + " ms, 100/100 expected");
        SettingsData.reduceMotion = was;
    }

    function matrix() {
        checkFades();
        for (let i = 0; i < rows.children.length - 1; i++) {
            const r = rows.children[i];
            const tag = r.width + " px, kind " + r.kind;
            check(tag, r);
            const segs = find(r, c => c.objectName === "segments");
            for (const s of segs.children) {
                if (s.height === undefined || s.width <= 0)
                    continue;
                if (Math.round(s.height) < 44)
                    fail(tag + ": a segment is " + s.height + " px high, 44 expected");
                const l = find(s, c => c.text !== undefined && c.font !== undefined && c.text !== "");
                if (l && l.font.pixelSize !== 14)
                    fail(tag + ": a choice label is " + l.font.pixelSize + " px, 14 expected");
            }
            const strip = find(r, c => c.objectName === "strip");
            if (strip.pad !== 4 || strip.padX !== 8)
                fail(tag + ": strip margins are " + strip.pad + "/" + strip.padX + ", 4/8 expected");
            const chip = chipShown(r);
            if (chip !== (r.kind === 1 || r.kind === 3))
                fail(tag + ": chip " + chip + " is wrong");
            if (r.kind === 0 && r.view.selected !== "")
                fail(tag + ": greyed row has a selection");
            if (r.kind === 0 && !find(r, c => c.objectName === "control" && c.width === 44 && c.height === 44))
                fail(tag + ": the guide mark is missing or not 44 px");
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (root.next())
                return;
            stop();
            console.warn(root.failures.length === 0 ? "OK: timer-end row" : root.failures.length + " problems");
            Qt.exit(root.failures.length === 0 ? 0 : 1);
        }
    }
}
