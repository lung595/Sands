import QtQuick
import QtTest
import "../../scripts/preview/mock"
import "../../components/settings"

// The visual alert rows of "Alerts & sounds" with real clicks: the three kind
// cards, the screen list ("Show on"), the dune style cards (each of the three styles can be picked), the
// full-screen switch, the moment, and "Test the alarm", which asks the daemon.
// Run: tests/qml-page/run.sh
Item {
    id: root
    width: 404
    height: 1600

    FakeDaemon {
        id: fake
    }

    // Stands for the DMS settings host: an in-memory store
    Item {
        id: host
        width: parent.width
        property var saved: ({})
        function loadValue(key, fallback) {
            return key in saved ? saved[key] : fallback;
        }
        function saveValue(key, value) {
            const next = Object.assign({}, saved);
            next[key] = value;
            saved = next;
        }

        AlertsSection {
            id: section
            daemon: fake
            // Two screens, as on a desk with a second monitor
            screens: [
                {
                    "name": "DP-2",
                    "model": "Wide 27"
                },
                {
                    "name": "HDMI-A-1",
                    "model": ""
                }
            ]
            soundOptions: [
                {
                    "label": "Hourglass",
                    "value": "default"
                }
            ]
        }
    }

    // A second page whose store already holds another style than the default
    Item {
        id: oldHost
        width: parent.width
        y: 1700
        visible: false
        function loadValue(key, fallback) {
            return key === "duneStyle" ? "wind" : fallback;
        }
        function saveValue(key, value) {
        }

        AlertsSection {
            id: oldSection
            daemon: null
            soundOptions: []
        }
    }

    TestCase {
        name: "AlertRows"
        when: windowShown

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
        function row(key, from) {
            return find(from || section, c => c.settingKey === key);
        }
        function card(key, value, from) {
            return find(row(key, from), c => c.objectName === "card-" + value);
        }
        function click(item) {
            // Cards are rebuilt when their options change: let the Flow place them first
            wait(30);
            mouseClick(item, item.width / 2, item.height / 2);
        }

        function init() {
            // Rows read the store one tick after they are built
            tryCompare(row("alertKind"), "ready", true);
            row("alertKind").value = "dune";
            row("duneStyle").value = "grains";
            row("alertScreen").value = "all";
            section.screens = twoScreens;
            fake.haloAvailable = true;
            fake.alertShowing = false;
            fake.alertTests = 0;
            fake.previews = [];
        }

        readonly property var twoScreens: [
            {
                "name": "DP-2",
                "model": "Wide 27"
            },
            {
                "name": "HDMI-A-1",
                "model": ""
            }
        ]
        function dropdown(key) {
            return find(row(key), c => c.dropdownWidth !== undefined && c.options !== undefined);
        }

        function test_screenRowDefaultsToAllScreens() {
            const r = row("alertScreen");
            compare(r.label, "Show on");
            compare(r.defaultValue, "all");
            compare(r.value, "all");
            verify(r.visible && r.height > 0);
            compare(dropdown("alertScreen").currentValue, "All screens");
            compare(dropdown("alertScreen").options, ["All screens", "Active screen", "Wide 27 (DP-2)", "HDMI-A-1"]);
            // Right under the kind cards, above the dune style
            verify(r.y > row("alertKind").y && r.y < row("duneStyle").y);
        }

        function test_screenRowSavesTheChoice() {
            const d = dropdown("alertScreen");
            d.valueChanged("Active screen");
            compare(host.saved.alertScreen, "focused");
            compare(d.currentValue, "Active screen");
            d.valueChanged("Wide 27 (DP-2)");
            compare(host.saved.alertScreen, "DP-2");
            d.valueChanged("HDMI-A-1");
            compare(host.saved.alertScreen, "HDMI-A-1");
            d.valueChanged("All screens");
            compare(host.saved.alertScreen, "all");
        }

        function test_screenRowFollowsThePluggedScreens() {
            const d = dropdown("alertScreen");
            d.valueChanged("HDMI-A-1");
            // The saved screen is unplugged: still shown, marked, nothing rewritten
            section.screens = [twoScreens[0]];
            compare(d.options, ["All screens", "Active screen", "Wide 27 (DP-2)", "HDMI-A-1 (not connected)"]);
            compare(d.currentValue, "HDMI-A-1 (not connected)");
            compare(host.saved.alertScreen, "HDMI-A-1");
            // Plugged again
            section.screens = twoScreens;
            compare(d.options, ["All screens", "Active screen", "Wide 27 (DP-2)", "HDMI-A-1"]);
            compare(d.currentValue, "HDMI-A-1");
            // A third screen arrives while the page is open
            section.screens = twoScreens.concat([
                {
                    "name": "eDP-1",
                    "model": "Laptop"
                }
            ]);
            compare(d.options.length, 5);
            compare(d.options[4], "Laptop (eDP-1)");
            // No screen list at all
            section.screens = [];
            compare(d.options, ["All screens", "Active screen", "HDMI-A-1 (not connected)"]);
        }

        function test_screenRowHiddenForNone() {
            click(card("alertKind", "halo"));
            verify(row("alertScreen").visible);
            click(card("alertKind", "none"));
            verify(!row("alertScreen").visible);
            click(card("alertKind", "dune"));
            verify(row("alertScreen").visible);
        }

        function test_screenRowHasNoLongDash() {
            const r = row("alertScreen");
            const texts = [r.label, r.description].concat(dropdown("alertScreen").options);
            for (const t of texts)
                verify(String(t).indexOf("\u2014") < 0, t);
        }

        function test_defaults() {
            compare(row("alertKind").defaultValue, "dune");
            compare(row("duneStyle").defaultValue, "grains");
            compare(row("alertWhen").defaultValue, "always");
            compare(row("duneOverFullscreen").defaultValue, false);
            verify(card("alertKind", "dune").selected);
            verify(card("duneStyle", "grains").selected);
            for (const k of ["alertKind", "alertScreen", "duneStyle", "duneOverFullscreen", "alertWhen", "testAlarm"])
                verify(row(k).visible && row(k).height > 0, k + " is shown");
        }

        function test_kindCardsSaveUnderTheDaemonKey() {
            click(card("alertKind", "halo"));
            compare(host.saved.alertKind, "halo");
            verify(card("alertKind", "halo").selected);
            // The dune rows leave with the dune; the moment stays
            verify(!row("duneStyle").visible);
            verify(!row("duneOverFullscreen").visible);
            verify(row("alertWhen").visible);
            click(card("alertKind", "none"));
            compare(host.saved.alertKind, "none");
            verify(!row("alertWhen").visible);
            verify(row("testAlarm").visible);
            click(card("alertKind", "dune"));
            compare(host.saved.alertKind, "dune");
            verify(row("duneStyle").visible);
        }

        function test_everyStyleCanBePicked() {
            for (const v of ["wind", "wave", "grains"]) {
                const c = card("duneStyle", v);
                verify(c.usable, v + " can be picked");
                compare(c.opacity, 1);
                verify(find(c, t => t.text === "Not available yet") === null, v + " has no greyed note");
                click(c);
                compare(row("duneStyle").value, v);
                compare(host.saved.duneStyle, v);
                verify(c.selected);
            }
        }

        function test_savedStyleShowsItsOwnCard() {
            tryCompare(row("duneStyle", oldSection), "ready", true);
            compare(row("duneStyle", oldSection).value, "wind");
            verify(card("duneStyle", "wind", oldSection).selected);
            verify(!card("duneStyle", "grains", oldSection).selected);
        }

        function test_fullScreenSwitchSaves() {
            const sw = row("duneOverFullscreen");
            sw.value = true;
            compare(host.saved.duneOverFullscreen, true);
            sw.value = false;
            compare(host.saved.duneOverFullscreen, false);
        }

        function test_momentSaves() {
            row("alertWhen").value = "muted";
            compare(host.saved.alertWhen, "muted");
            row("alertWhen").value = "always";
            compare(host.saved.alertWhen, "always");
        }

        function test_testTheAlarmAsksTheDaemon() {
            const button = find(row("testAlarm"), c => c.objectName === "testAlarmButton");
            verify(button.enabled);
            click(button);
            compare(fake.alertTests, 1);
            compare(fake.previews, ["default"]);
            // Held while an alert is on screen
            fake.alertShowing = true;
            verify(!button.enabled);
            click(button);
            compare(fake.alertTests, 1);
            fake.alertShowing = false;
            verify(button.enabled);
        }

        function test_testTheAlarmNeedsTheDaemon() {
            const button = find(row("testAlarm", oldSection), c => c.objectName === "testAlarmButton");
            verify(!button.enabled);
        }

        function test_haloGreyedWithoutLayerShell() {
            fake.haloAvailable = false;
            const c = card("alertKind", "halo");
            verify(!c.usable);
            verify(find(section, t => t.text !== undefined && String(t.text).indexOf("Wayland layer shell, which") >= 0).visible);
            click(c);
            compare(row("alertKind").value, "dune");
            fake.haloAvailable = true;
            verify(card("alertKind", "halo").usable);
        }
    }
}
