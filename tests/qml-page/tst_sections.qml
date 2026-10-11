import QtQuick
import QtTest
import "../../scripts/preview/mock"
import "../../components/settings/Sections.js" as Sections

// Every settings section is built inside the page, in the same kind of host as DMS
// (a Flickable column), and walking the rail repeatedly shows exactly one at a time.
// NAK-708: building a section on demand crashed Quickshell, so none may be built late.
// Run: tests/qml-page/run.sh
Item {
    id: root
    width: 404
    height: 400

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: host.height
        clip: true

        SettingsCase {
            id: host
            pageWidth: 404
        }
    }

    TestCase {
        name: "SettingsSections"
        when: windowShown

        readonly property var ids: ["timers", "appearance", "alerts", "help"]

        function find(item, name) {
            for (const c of item.children) {
                if (c.objectName === name)
                    return c;
                const hit = find(c, name);
                if (hit)
                    return hit;
            }
            return null;
        }

        // Settings rows that carry a key and are really shown, per section
        function shownRows(item) {
            let n = 0;
            for (const c of item.children) {
                if (!c.visible)
                    continue;
                if (c.settingKey !== undefined)
                    n++;
                n += shownRows(c);
            }
            return n;
        }

        // Settings rows that carry a key, shown or hidden: a row built late would be missing
        function builtRows(item) {
            let n = 0;
            for (const c of item.children) {
                if (c.settingKey !== undefined)
                    n++;
                n += builtRows(c);
            }
            return n;
        }

        // Fails on a page that builds sections on demand (the old Loader page)
        function test_everySectionIsBuiltBeforeAnyOpen() {
            const sp = find(host, "settingsPage");
            const wanted = Sections.SETTINGS.filter(s => !s.pending && ids.indexOf(s.section) >= 0).length;
            compare(builtRows(sp), wanted);
        }

        function test_walkTheRailRepeatedly() {
            const sp = find(host, "settingsPage");
            for (let round = 0; round < 25; round++) {
                for (const id of ids) {
                    sp.open(id, "");
                    wait(0);
                    compare(sp.section, id);
                    verify(sp.implicitHeight > 0, id + " has a height");
                    verify(shownRows(sp) > 0 || id === "help", id + " shows rows");
                }
            }
        }
    }
}
